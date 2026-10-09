"""
    OrdinaryDiffEqInterpolation{cacheType} <: SciMLBase.AbstractDiffEqInterpolation

Abstract supertype for the dense-output interpolation object attached to a
solution. Given a saved timeseries plus derivative (`k`) history it evaluates the
continuous extension. See [`InterpolationData`](@ref) for the concrete type.
"""
abstract type OrdinaryDiffEqInterpolation{cacheType} <:
SciMLBase.AbstractDiffEqInterpolation end

"""
    InterpolationData(f, timeseries, ts, ks, alg_choice, dense, cache, differential_vars, sensitivitymode)

Concrete [`OrdinaryDiffEqInterpolation`](@ref) storing everything needed to
evaluate the continuous solution: the RHS `f`, the saved states `timeseries` at
times `ts`, the stage-derivative history `ks`, the per-step `alg_choice` (for
composite algorithms), whether `dense` output is available, the solver `cache`,
the `differential_vars` mask (for DAEs), and a `sensitivitymode` flag. Calling
`(interp)(tvals, idxs, deriv, p, continuity)` performs the interpolation.
"""
struct InterpolationData{
        F, uType, tType, kType, algType <: Union{Nothing, Vector{Int}}, cacheType, DV,
    } <:
    OrdinaryDiffEqInterpolation{cacheType}
    f::F
    timeseries::uType
    ts::tType
    ks::kType
    alg_choice::algType
    dense::Bool
    cache::cacheType
    differential_vars::DV
    sensitivitymode::Bool
    # Warm-start hint for the interval search in scalar `ode_interpolation`;
    # see `TsSearchHint`.
    ts_hint::TsSearchHint{tType}
    # Intervals of a step that a callback cut short. `cut_index` holds the sorted
    # indices `i` of `ks` whose interval `(ts[i-1], ts[i]]` is a cut step, and
    # `cut_dt` the length of the completed step for each. The dense output of such
    # an interval is the curve of the completed step. See `_cut_dt`.
    cut_index::Vector{Int}
    cut_dt::tType
end

function InterpolationData(
        f, timeseries, ts, ks, alg_choice, dense, cache,
        differential_vars, sensitivitymode, ts_hint::TsSearchHint
    )
    return InterpolationData(
        f, timeseries, ts, ks, alg_choice, dense, cache,
        differential_vars, sensitivitymode, ts_hint, Int[], similar(ts, 0)
    )
end

# Downstream packages (e.g. StochasticDiffEq) construct `InterpolationData`
# positionally with these nine arguments; the hint then starts on the robust
# gallop strategy and re-selects itself as the grid is probed.
function InterpolationData(
        f, timeseries, ts, ks, alg_choice, dense, cache,
        differential_vars, sensitivitymode
    )
    return InterpolationData(
        f, timeseries, ts, ks, alg_choice, dense, cache,
        differential_vars, sensitivitymode, TsSearchHint(ts)
    )
end

@inline _ts_hint(id::InterpolationData) = id.ts_hint

# Cut steps: see `_interval_curve` and `push_cut!`.
@inline function _cut_dt(id::InterpolationData, i₊)
    idx = id.cut_index
    isempty(idx) && return nothing
    j = searchsortedfirst(idx, i₊)
    return (j <= length(idx) && @inbounds(idx[j]) == i₊) ? @inbounds(id.cut_dt[j]) : nothing
end

function _truncate_cuts!(id::InterpolationData, n)
    while !isempty(id.cut_index) && last(id.cut_index) > n
        pop!(id.cut_index)
        pop!(id.cut_dt)
    end
    return nothing
end

@static if isdefined(SciMLBase, :enable_interpolation_sensitivitymode)
    function SciMLBase.enable_interpolation_sensitivitymode(interp::InterpolationData)
        InterpolationData(
            interp.f, interp.timeseries, interp.ts, interp.ks,
            interp.alg_choice, interp.dense, interp.cache,
            interp.differential_vars, true, TsSearchHint(interp.ts),
            interp.cut_index, interp.cut_dt
        )
    end
end

function SciMLBase.interp_summary(
        interp::OrdinaryDiffEqInterpolation{
            cacheType,
        }
    ) where {
        cacheType,
    }
    return SciMLBase.interp_summary(cacheType, interp.dense)
end
function SciMLBase.interp_summary(::Type{cacheType}, dense::Bool) where {cacheType}
    return dense ? "3rd order Hermite" : "1st order linear"
end
function SciMLBase.interp_summary(
        ::Type{cacheType},
        dense::Bool
    ) where {cacheType <: CompositeCache}
    if !dense
        return "1st order linear"
    end
    caches = fieldtype(cacheType, :caches)
    return join([SciMLBase.interp_summary(ct, dense) for ct in fieldtypes(caches)], ", ")
end

function (interp::InterpolationData)(tvals, idxs, deriv, p, continuity::Symbol = :left)
    return ode_interpolation(tvals, interp, idxs, deriv, p, continuity)
end
function (interp::InterpolationData)(val, tvals, idxs, deriv, p, continuity::Symbol = :left)
    return ode_interpolation!(val, tvals, interp, idxs, deriv, p, continuity)
end

function InterpolationData(id::InterpolationData, f)
    return InterpolationData(
        f, id.timeseries,
        id.ts,
        id.ks,
        id.alg_choice,
        id.dense,
        id.cache,
        id.differential_vars,
        id.sensitivitymode,
        TsSearchHint(id.ts),
        id.cut_index,
        id.cut_dt
    )
end

# strip interpolation of function information
function SciMLBase.strip_interpolation(id::InterpolationData)
    cache = strip_cache(id.cache)

    return InterpolationData(
        nothing, id.timeseries,
        id.ts,
        id.ks,
        id.alg_choice,
        id.dense,
        cache,
        id.differential_vars,
        id.sensitivitymode,
        TsSearchHint(id.ts),
        id.cut_index,
        id.cut_dt
    )
end

"""
    strip_cache(cache)

Return a lightweight copy of `cache` with all fields set to `nothing`, used by
`SciMLBase.strip_interpolation` to drop the (potentially large) working buffers
from a solution's interpolation object before serialization. Has a special path
for [`DefaultCache`](@ref).

# Developer API

Solver extensions may specialize this hook for their cache types. End-user code
should call `solve` and use solution APIs, rather than construct caches or
depend on cache fields and their serialized representation.
"""
function strip_cache(cache)
    if !(cache isa OrdinaryDiffEqCore.DefaultCache)
        cache = ConstructionBase.constructorof(typeof(cache))(
            [
                nothing
                    for name in
                    fieldnames(typeof(cache))
            ]...
        )
    else
        # need to do something special for default cache
        cache = OrdinaryDiffEqCore.DefaultCache{
            Nothing, Nothing, Nothing, Nothing,
            Nothing, Nothing, Nothing, Nothing,
        }(nothing, nothing, 0, nothing)
    end

    return cache
end
