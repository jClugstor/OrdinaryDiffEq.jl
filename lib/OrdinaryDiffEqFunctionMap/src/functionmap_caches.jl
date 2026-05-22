@cache struct FunctionMapCache{uType, rateType} <: OrdinaryDiffEqMutableCache
    u::uType
    uprev::uType
    tmp_cache::TmpCache{uType, rateType, Nothing}
end
get_fsalfirstlast(cache::FunctionMapCache, u) = (nothing, nothing)

function alg_cache(
        alg::FunctionMap, u, rate_prototype, ::Type{uEltypeNoUnits},
        ::Type{uBottomEltypeNoUnits}, ::Type{tTypeNoUnits}, uprev, uprev2, f, t,
        dt, reltol, p, calck,
        ::Val{true}, verbose;
        preallocate_init_dt_extras::Bool = true
    ) where {uEltypeNoUnits, uBottomEltypeNoUnits, tTypeNoUnits}
    tmp_cache = build_tmp_cache(u, rate_prototype, Nothing; need_tmp = true, preallocate_init_dt_extras = preallocate_init_dt_extras)
    return FunctionMapCache(u, uprev, tmp_cache)
end


struct FunctionMapConstantCache <: OrdinaryDiffEqConstantCache end

function alg_cache(
        alg::FunctionMap, u, rate_prototype, ::Type{uEltypeNoUnits},
        ::Type{uBottomEltypeNoUnits}, ::Type{tTypeNoUnits}, uprev, uprev2, f, t,
        dt, reltol, p, calck,
        ::Val{false}, verbose
    ) where {uEltypeNoUnits, uBottomEltypeNoUnits, tTypeNoUnits}
    return FunctionMapConstantCache()
end

isdiscretecache(cache::Union{FunctionMapCache, FunctionMapConstantCache}) = true
