#!/usr/bin/env julia
# Migrate OrdinaryDiffEq.jl caches to use unified TmpCache.
#
# Pass A — `*_caches.jl` files:
#   * For each `@cache struct <Name>{...} <: OrdinaryDiffEqMutableCache ... end`
#     - Detect fields named `utilde`, `tmp`, `atmp`, `linsolve_tmp`.
#     - Remove those field declarations.
#     - Add `tmp_cache::TmpCacheType` field at the position of the first
#       removed field (preserves a reasonable position).
#     - Replace `uNoUnitsType` in the parameter list with `TmpCacheType`
#       (if `atmp::uNoUnitsType` was removed AND no other field uses
#       `uNoUnitsType`).
#   * For each matching `alg_cache(alg::<Alg>, ... ::Val{true}, ...)`
#     - Remove inline lines: `utilde = zero(u)`, `tmp = zero(u)`,
#       `linsolve_tmp = zero(rate_prototype)`,
#       `atmp = similar(u, uEltypeNoUnits)` + `recursivefill!(atmp, false)`.
#     - Insert a `tmp_cache = build_tmp_cache(...)` call right before the
#       `return <CacheName>(...)`.
#     - Update the constructor call to replace removed args with
#       `tmp_cache`.
#     - Add `; preallocate_init_dt_extras::Bool = true` kwarg to the
#       function signature.
#
# Pass B — all other `.jl` files under `lib/`:
#   * Substitute `cache.tmp`, `cache.atmp`, `cache.utilde`,
#     `cache.linsolve_tmp` with the `cache.tmp_cache.*` equivalents
#     (only when preceded by literal `cache.`, not `prob.`/`nlsolver.`/etc.)
#   * Rewrite destructuring `(; ..., {fields}, ...) = cache` blocks so
#     that the `tmp/utilde/atmp/linsolve_tmp` names come from
#     `cache.tmp_cache` and the rest stay on the regular `= cache` line.
#
# This script is intentionally conservative: it bails on unfamiliar shapes
# and emits a `# TMPCACHE: review` marker so a human can finish.

using Base.Filesystem

const LIB_DIR = joinpath(dirname(dirname(@__FILE__)), "lib")

# Map old field name -> (new dotted access, need_kw flag)
const FIELD_RENAMES = Dict(
    "tmp"          => ("tmp_cache.tmp",       :need_tmp),
    "utilde"       => ("tmp_cache.tmp2",      :need_tmp2),
    "atmp"         => ("tmp_cache.atmp",      :need_atmp),
    "linsolve_tmp" => ("tmp_cache.rate_tmp",  :need_rate_tmp),
)

const OLD_FIELDS = collect(keys(FIELD_RENAMES))

# ── Pass A: cache struct + alg_cache rewrites ────────────────────────────────

"""
Rewrite a single `@cache struct Name{...} <: OrdinaryDiffEqMutableCache ... end`
block, returning (new_block_text, removed::Vector{String}).
`removed` is the set of old fields actually found and removed.
"""
function rewrite_cache_struct(block::AbstractString)
    removed = String[]
    new_lines = String[]
    inserted_tmp_cache = false
    for line in split(block, '\n'; keepempty=true)
        stripped = strip(line)
        matched = false
        for f in OLD_FIELDS
            re = Regex("^\\s*$(f)::\\w+\\s*\$")
            if occursin(re, line)
                push!(removed, f)
                matched = true
                if !inserted_tmp_cache
                    # indent like the matched line
                    indent = match(r"^(\s*)", line).captures[1]
                    push!(new_lines, "$(indent)tmp_cache::TmpCacheType")
                    inserted_tmp_cache = true
                end
                break
            end
        end
        matched || push!(new_lines, line)
    end
    new_block = join(new_lines, '\n')
    # If we removed `atmp` and no other field still uses `uNoUnitsType`,
    # swap `uNoUnitsType` → `TmpCacheType` in the parameter list. Otherwise
    # just append `TmpCacheType` after the first parameter that's missing.
    if !isempty(removed)
        if "atmp" in removed && !occursin(r"::uNoUnitsType\b", new_block)
            new_block = replace(new_block, r"\buNoUnitsType\b" => "TmpCacheType"; count=1)
        else
            # Insert TmpCacheType into the type parameter list (heuristic:
            # add before `StageLimiter` if present, else just after `rateType`).
            if occursin("StageLimiter", new_block)
                new_block = replace(new_block, "StageLimiter" => "TmpCacheType, StageLimiter"; count=1)
            else
                new_block = replace(new_block, r"\brateType\b" => "rateType, TmpCacheType"; count=1)
            end
        end
    end
    return new_block, removed
end

"""
Rewrite a single `function alg_cache(... ::Val{true} ...) ... end` block,
given the set of fields that were removed from the struct.
"""
function rewrite_alg_cache(block::AbstractString, removed::Vector{String})
    isempty(removed) && return block
    lines = split(block, '\n'; keepempty=true)
    new_lines = String[]
    skip_next_recursivefill = false
    for line in lines
        if skip_next_recursivefill
            skip_next_recursivefill = false
            occursin("recursivefill!(atmp", line) && continue
        end
        # Drop inline allocation lines
        if occursin(r"^\s*utilde\s*=\s*zero\(u\)\s*$", line) && "utilde" in removed
            continue
        elseif occursin(r"^\s*tmp\s*=\s*zero\(u\)\s*$", line) && "tmp" in removed
            continue
        elseif occursin(r"^\s*linsolve_tmp\s*=\s*zero\(rate_prototype\)\s*$", line) && "linsolve_tmp" in removed
            continue
        elseif occursin(r"^\s*atmp\s*=\s*similar\(u,\s*uEltypeNoUnits\)\s*$", line) && "atmp" in removed
            skip_next_recursivefill = true
            continue
        end
        push!(new_lines, line)
    end

    # Build `need_*` kwargs
    needs = String[]
    "tmp" in removed         && push!(needs, "need_tmp = true")
    "utilde" in removed      && push!(needs, "need_tmp2 = true")
    "atmp" in removed        && push!(needs, "need_atmp = true")
    "linsolve_tmp" in removed && push!(needs, "need_rate_tmp = true")
    need_block = join(needs, ", ")

    # Insert tmp_cache build line right before the final `return <CacheName>(...)`
    # and rewrite the constructor call to swap removed args for `tmp_cache`.
    text = join(new_lines, '\n')

    # Find the constructor return. Match `return <Name>(` and consume balanced parens.
    m = match(r"(return\s+)(\w+)\s*\(", text)
    if m === nothing
        return text * "\n# TMPCACHE: review — couldn't find return constructor\n"
    end
    name = m.captures[2]
    start_idx = m.offset + ncodeunits(m.match) - 1   # the `(` index (1-based)
    depth = 1
    i = start_idx + 1
    while i <= lastindex(text) && depth > 0
        c = text[i]
        if c == '('
            depth += 1
        elseif c == ')'
            depth -= 1
        end
        i = nextind(text, i)
    end
    depth == 0 || return text * "\n# TMPCACHE: review — unmatched parens in constructor\n"
    end_idx = prevind(text, i)              # index of the matching ')'
    inside = text[(start_idx + 1):(end_idx - 1)]
    # Split args, respecting nesting.
    args = split_top_level_args(inside)
    new_args = String[]
    inserted = false
    for a in args
        stripped_a = strip(a)
        if stripped_a in removed
            if !inserted
                push!(new_args, " tmp_cache")
                inserted = true
            end
        else
            push!(new_args, a)
        end
    end
    # If none of the removed fields appear as named args in the constructor,
    # the alg_cache is using inline positional arguments (e.g. `zero(u)` in
    # place of a named `tmp`). Positional alignment depends on struct field
    # order, which the script cannot reliably reconstruct — bail out with a
    # review marker so a human can finish.
    if !inserted
        rlist = join(removed, ", ")
        marker = string("\n# TMPCACHE: review — alg_cache constructor uses inline ",
                        "positional args for removed fields ($rlist); rewrite by hand.\n")
        return text * marker
    end
    new_inside = join(new_args, ",")
    new_call = "return $name($new_inside)"
    text = string(text[1:prevind(text, m.offset)], new_call, text[(end_idx + 1):end])

    # Insert build_tmp_cache line before the return.
    build_line = "    tmp_cache = build_tmp_cache(u, rate_prototype, uEltypeNoUnits; $need_block, preallocate_init_dt_extras = preallocate_init_dt_extras)"
    rm = match(r"(\n\s*)return\s+\w+\s*\(", text)
    if rm !== nothing
        text = string(text[1:prevind(text, rm.offset + 1)],
                      build_line, text[rm.offset:end])
    end

    # Add `; preallocate_init_dt_extras::Bool = true` to the function
    # signature. We insert just before the `where {...}` clause or right
    # before `)` that closes the signature args.
    text = inject_preallocate_kwarg(text)

    return text
end

function split_top_level_args(s::AbstractString)
    args = String[]
    depth = 0
    last = firstindex(s)
    for i in eachindex(s)
        c = s[i]
        if c == '(' || c == '[' || c == '{'
            depth += 1
        elseif c == ')' || c == ']' || c == '}'
            depth -= 1
        elseif c == ',' && depth == 0
            push!(args, s[last:prevind(s, i)])
            last = nextind(s, i)
        end
    end
    push!(args, s[last:end])
    return args
end

function inject_preallocate_kwarg(text::AbstractString)
    # The alg_cache signature ends with `::Val{true}, verbose\n    ) where {...}`.
    # Inject `; preallocate_init_dt_extras::Bool = true` before the `)`.
    m = match(r"(::Val\{true\}\s*,\s*verbose)(\s*)(\))", text)
    if m === nothing
        return text * "\n# TMPCACHE: review — couldn't inject preallocate_init_dt_extras kwarg\n"
    end
    replacement = string(m.captures[1], ";\n        preallocate_init_dt_extras::Bool = true",
                         m.captures[2], m.captures[3])
    return string(text[1:prevind(text, m.offset)], replacement,
                  text[(m.offset + ncodeunits(m.match)):end])
end

"""
Replace every regex `re` match in `text` using a function `f(match)::String`.
Returns the rewritten text.
"""
function replace_all_matches(f, text::AbstractString, re::Regex)
    out = IOBuffer()
    cursor = 1
    while true
        m = match(re, text, cursor)
        m === nothing && break
        write(out, text[cursor:prevind(text, m.offset)])
        write(out, f(m))
        cursor = m.offset + ncodeunits(m.match)
    end
    write(out, text[cursor:end])
    return String(take!(out))
end

"""
Process one *_caches.jl file. Two independent passes: rewrite all
`@cache struct` blocks (building a map of cache_name → removed fields),
then rewrite all `alg_cache(... ::Val{true} ...)` functions using that map.
"""
function process_cache_file(text::AbstractString)
    n_structs = Ref(0)
    n_funs = Ref(0)
    cache_info = Dict{String, Vector{String}}()

    # Pass 1 — structs (matches `@cache struct` and `@cache mutable struct`)
    struct_pat = r"@cache (?:mutable )?struct[^\n]*\n(?:.*\n)*?end\n"
    text = replace_all_matches(text, struct_pat) do m
        n_structs[] += 1
        nm = match(r"@cache (?:mutable )?struct\s+(\w+)", m.match)
        new_struct, removed = rewrite_cache_struct(m.match)
        if nm !== nothing && !isempty(removed)
            cache_info[nm.captures[1]] = removed
        end
        return new_struct
    end

    # Pass 2 — alg_cache functions, one per known cache name.
    # Anchor `function alg_cache(` and `end` at the start of a line so we
    # only match the outermost function, not nested `end`s in if-blocks.
    fun_pat = r"^function alg_cache\((?:.*\n)*?^end\n"m
    text = replace_all_matches(text, fun_pat) do m
        body = m.match
        # Only Val{true} functions need rewriting; Val{false} returns the
        # constant cache and has no buffers to move.
        occursin("::Val{true}", body) || return body
        # Find which cache this function returns; only proceed if its
        # struct was rewritten.
        rm = match(r"return\s+(\w+)\s*\(", body)
        rm === nothing && return body
        name = rm.captures[1]
        haskey(cache_info, name) || return body
        n_funs[] += 1
        return rewrite_alg_cache(body, cache_info[name])
    end

    return text, n_structs[], n_funs[]
end

# ── Pass B: consumer-file rewrites (perform_step, addsteps, interpolants) ────

"""
Rewrite consumer code (any `.jl` file outside *_caches.jl) by substituting
`cache.<field>` and rewriting destructuring `(; ..., field, ...) = cache`.
"""
function rewrite_consumer(text::AbstractString)
    out = text
    # 1. Substitute plain `cache.<field>` -> `cache.tmp_cache.<remap>`.
    #    Use word boundaries to avoid matching `_cache.tmp` etc.
    for f in OLD_FIELDS
        new_dot, _ = FIELD_RENAMES[f]
        re = Regex("\\bcache\\.$(f)\\b")
        out = replace(out, re => "cache.$new_dot")
    end
    # 2. Rewrite destructuring lines: `(; a, b, tmp, c, ...) = cache`.
    out = replace(out, r"\(;([^)]*)\)\s*=\s*cache\b" => function(s)
        m = match(r"\(;([^)]*)\)\s*=\s*cache\b", s)
        inner = m.captures[1]
        parts = [strip(x) for x in split(inner, ",")]
        kept = String[]
        rebinds = String[]
        for p in parts
            isempty(p) && continue
            if p in OLD_FIELDS
                new_dot, _ = FIELD_RENAMES[p]
                push!(rebinds, "$p = cache.$new_dot")
            else
                push!(kept, p)
            end
        end
        if isempty(rebinds)
            return s
        end
        kept_str = isempty(kept) ? "" : "(; " * join(kept, ", ") * ") = cache\n    "
        return kept_str * join(rebinds, "\n    ")
    end)
    return out
end

# ── Driver ──────────────────────────────────────────────────────────────────

function process_file(path::AbstractString)
    text = read(path, String)
    new_text = if endswith(path, "_caches.jl")
        nt, ns, nf = process_cache_file(text)
        printstyled("  caches: $(basename(path))  structs=$ns alg_caches=$nf\n";
                    color=:cyan)
        nt
    elseif endswith(path, ".jl") && !occursin("/test/", path)
        rewrite_consumer(text)
    else
        text
    end
    if new_text != text
        write(path, new_text)
    end
end

function walk(root::AbstractString)
    for (dir, _, files) in walkdir(root)
        # Skip test directories
        occursin(joinpath("test"), dir) && continue
        for f in files
            endswith(f, ".jl") && process_file(joinpath(dir, f))
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS)
        @info "Usage: julia migrate_to_tmpcache.jl <subdir-of-lib>..."
        @info "  e.g.: julia migrate_to_tmpcache.jl OrdinaryDiffEqLowOrderRK"
        exit(1)
    end
    for sub in ARGS
        path = joinpath(LIB_DIR, sub)
        isdir(path) || (@warn "Not a directory: $path"; continue)
        @info "Migrating $sub"
        walk(path)
    end
end
