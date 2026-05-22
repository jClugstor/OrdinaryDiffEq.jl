#!/usr/bin/env julia
# Rework pass: convert `tmp_cache::TmpCacheType` (anonymous parameter) into
# `tmp_cache::TmpCache{uType, rateType, uNoUnitsType}` (re-uses existing
# cache type params) or `tmp_cache::TmpCache{uType, rateType, Nothing}`
# (for caches that don't need atmp), and adjust the cache's type-parameter
# list and any `build_tmp_cache` call accordingly.
#
# Heuristic for adaptive vs non-adaptive:
#   * If the alg_cache for a cache passes `need_atmp = true` to
#     `build_tmp_cache`, the cache is treated as "needs uNoUnitsType":
#       - rename `TmpCacheType` -> `uNoUnitsType` in the cache's parameter list
#       - field becomes `TmpCache{uType, rateType, uNoUnitsType}`
#   * Otherwise the cache is treated as "doesn't need atmp":
#       - drop `TmpCacheType` from the parameter list entirely
#       - field becomes `TmpCache{uType, rateType, Nothing}`
#       - the `build_tmp_cache(u, rate_prototype, uEltypeNoUnits; ...)`
#         call becomes `build_tmp_cache(u, rate_prototype, Nothing; ...)`
#         so the returned `TmpCache` is parameterized with `Nothing` and
#         no `atmp` buffer is allocated even when `extras = true`.

using Base.Filesystem

const LIB_DIR = joinpath(dirname(dirname(@__FILE__)), "lib")

"""
Determine the set of cache names whose `alg_cache` calls `build_tmp_cache`
with `need_atmp = true`. Returns a Set{String} of those cache type names.
"""
function find_atmp_caches(text::AbstractString)
    atmp_caches = Set{String}()
    # Each alg_cache function body ends with `return <Name>(...)`. If the body
    # also contains `need_atmp = true`, the cache constructed in that return
    # is treated as adaptive (needs uNoUnitsType).
    fun_pat = r"^function alg_cache\((?:.*\n)*?^end\n"m
    for m in eachmatch(fun_pat, text)
        body = m.match
        occursin("need_atmp = true", body) || continue
        rm = match(r"return\s+(\w+)\s*\(", body)
        rm === nothing && continue
        push!(atmp_caches, rm.captures[1])
    end
    return atmp_caches
end

"""
Rewrite a `@cache (mutable )?struct Name{..., TmpCacheType, ...} ... tmp_cache::TmpCacheType ... end`
block. If `adaptive` is true, `TmpCacheType` is renamed to `uNoUnitsType`
and the field becomes `TmpCache{uType, rateType, uNoUnitsType}`. Otherwise,
`TmpCacheType` is dropped from the parameter list and the field becomes
`TmpCache{uType, rateType, Nothing}`.
"""
function rewrite_struct(block::AbstractString, adaptive::Bool)
    # Replace the field declaration.
    new_field = adaptive ?
        "tmp_cache::TmpCache{uType, rateType, uNoUnitsType}" :
        "tmp_cache::TmpCache{uType, rateType, Nothing}"
    block = replace(block, r"tmp_cache::TmpCacheType\b" => new_field)
    # Adjust the type-parameter list.
    if adaptive
        block = replace(block, r"\bTmpCacheType\b" => "uNoUnitsType")
    else
        # Drop `TmpCacheType` (and the adjacent `,` / whitespace) from the
        # type parameter list. Handle both `, TmpCacheType` and
        # `TmpCacheType,` (start of list).
        block = replace(block, r",\s*TmpCacheType\b" => "")
        block = replace(block, r"\bTmpCacheType\s*,\s*" => "")
    end
    return block
end

"""
For non-adaptive caches, change the `build_tmp_cache` call from
`build_tmp_cache(u, rate_prototype, uEltypeNoUnits; ...)` to
`build_tmp_cache(u, rate_prototype, Nothing; ...)`. The function call is
inside an alg_cache that returns `<cache_name>`.
"""
function rewrite_build_calls(text::AbstractString, non_adaptive_names::Set{String})
    isempty(non_adaptive_names) && return text
    fun_pat = r"^function alg_cache\((?:.*\n)*?^end\n"m
    out = IOBuffer()
    cursor = 1
    while true
        m = match(fun_pat, text, cursor)
        m === nothing && break
        write(out, text[cursor:prevind(text, m.offset)])
        body = m.match
        rm = match(r"return\s+(\w+)\s*\(", body)
        if rm !== nothing && rm.captures[1] in non_adaptive_names
            body = replace(body,
                r"build_tmp_cache\(u,\s*rate_prototype,\s*uEltypeNoUnits;" =>
                    "build_tmp_cache(u, rate_prototype, Nothing;")
        end
        write(out, body)
        cursor = m.offset + ncodeunits(m.match)
    end
    write(out, text[cursor:end])
    return String(take!(out))
end

function process_file(path::AbstractString)
    text = read(path, String)
    occursin("tmp_cache::TmpCacheType", text) || return
    atmp_caches = find_atmp_caches(text)

    # Pass A — rewrite struct blocks
    struct_pat = r"@cache (?:mutable )?struct[^\n]*\n(?:.*\n)*?end\n"
    non_adaptive_names = String[]
    out = IOBuffer()
    cursor = 1
    while true
        m = match(struct_pat, text, cursor)
        m === nothing && break
        write(out, text[cursor:prevind(text, m.offset)])
        block = m.match
        nm = match(r"@cache (?:mutable )?struct\s+(\w+)", block)
        if nm !== nothing && occursin("tmp_cache::TmpCacheType", block)
            name = nm.captures[1]
            adaptive = name in atmp_caches
            block = rewrite_struct(block, adaptive)
            adaptive || push!(non_adaptive_names, name)
        end
        write(out, block)
        cursor = m.offset + ncodeunits(m.match)
    end
    write(out, text[cursor:end])
    text = String(take!(out))

    # Pass B — adjust build_tmp_cache calls in alg_cache for non-adaptive caches
    text = rewrite_build_calls(text, Set(non_adaptive_names))

    write(path, text)
    printstyled("  $(basename(path))  adaptive=$(length(atmp_caches)) non_adaptive=$(length(non_adaptive_names))\n";
                color=:cyan)
end

function walk(root::AbstractString)
    for (dir, _, files) in walkdir(root)
        occursin(joinpath("test"), dir) && continue
        for f in files
            endswith(f, "_caches.jl") || continue
            process_file(joinpath(dir, f))
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS)
        # Apply to every sublib that contains `tmp_cache::TmpCacheType`.
        targets = String[]
        for entry in readdir(LIB_DIR)
            full = joinpath(LIB_DIR, entry)
            isdir(full) || continue
            for (d, _, files) in walkdir(full)
                for f in files
                    if endswith(f, "_caches.jl") &&
                            occursin("tmp_cache::TmpCacheType", read(joinpath(d, f), String))
                        push!(targets, entry)
                        @goto next_entry
                    end
                end
            end
            @label next_entry
        end
        unique!(targets)
        @info "Reworking sublibs: $(join(targets, ' '))"
        for t in targets
            walk(joinpath(LIB_DIR, t))
        end
    else
        for sub in ARGS
            path = joinpath(LIB_DIR, sub)
            isdir(path) || (@warn "Not a directory: $path"; continue)
            @info "Reworking $sub"
            walk(path)
        end
    end
end
