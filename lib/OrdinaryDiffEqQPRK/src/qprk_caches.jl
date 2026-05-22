struct QPRK98ConstantCache <: OrdinaryDiffEqConstantCache end

@cache struct QPRK98Cache{
        uType, rateType, uNoUnitsType, StageLimiter, StepLimiter, Thread,
    } <:
    OrdinaryDiffEqMutableCache
    u::uType
    uprev::uType
    fsalfirst::rateType
    k2::rateType
    k3::rateType
    k4::rateType
    k5::rateType
    k6::rateType
    k7::rateType
    k8::rateType
    k9::rateType
    k10::rateType
    k11::rateType
    k12::rateType
    k13::rateType
    k14::rateType
    k15::rateType
    k16::rateType
    tmp_cache::TmpCache{uType, rateType, uNoUnitsType}
    k::rateType
    stage_limiter!::StageLimiter
    step_limiter!::StepLimiter
    thread::Thread
end

get_fsalfirstlast(cache::QPRK98Cache, u) = (cache.fsalfirst, cache.k)

function alg_cache(
        alg::QPRK98, u, rate_prototype, ::Type{uEltypeNoUnits},
        ::Type{uBottomEltypeNoUnits}, ::Type{tTypeNoUnits},
        uprev, uprev2, f, t, dt, reltol, p, calck,
        ::Val{true}, verbose;
        preallocate_init_dt_extras::Bool = true
    ) where {uEltypeNoUnits, uBottomEltypeNoUnits, tTypeNoUnits}
    k1 = zero(rate_prototype)
    k2 = zero(rate_prototype)
    k3 = zero(rate_prototype)
    k4 = zero(rate_prototype)
    k5 = zero(rate_prototype)
    k6 = zero(rate_prototype)
    k7 = zero(rate_prototype)
    k8 = zero(rate_prototype)
    k9 = zero(rate_prototype)
    k10 = zero(rate_prototype)
    k11 = zero(rate_prototype)
    k12 = zero(rate_prototype)
    k13 = zero(rate_prototype)
    k14 = zero(rate_prototype)
    k15 = zero(rate_prototype)
    k16 = zero(rate_prototype)
    k = zero(rate_prototype)
    recursivefill!(atmp, false)
    tmp_cache = build_tmp_cache(u, rate_prototype, uEltypeNoUnits; need_tmp = true, need_tmp2 = true, need_atmp = true, preallocate_init_dt_extras = preallocate_init_dt_extras)
    return QPRK98Cache(
        u, uprev, k1, k2, k3, k4, k5, k6, k7, k8, k9, k10, k11, k12, k13, k14, k15,
        k16, tmp_cache, k, alg.stage_limiter!, alg.step_limiter!,
        alg.thread
    )
end

function alg_cache(
        ::QPRK98, u, rate_prototype, ::Type{uEltypeNoUnits},
        ::Type{uBottomEltypeNoUnits}, ::Type{tTypeNoUnits}, uprev, uprev2, f, t,
        dt, reltol, p, calck,
        ::Val{false}, verbose
    ) where {uEltypeNoUnits, uBottomEltypeNoUnits, tTypeNoUnits}
    return QPRK98ConstantCache()
end
