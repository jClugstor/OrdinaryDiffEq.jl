@inline function SciMLBase.get_tmp_cache(
        integrator,
        alg::Union{
            SSPRK22, SSPRK33, SSPRK53_2N1,
            SSPRK53_2N2, SSPRK43, SSPRK432,
            SSPRK932,
        },
        cache::OrdinaryDiffEqMutableCache
    )
    # `k` (rate-typed) stays first to preserve the positional `first(tup)`
    # contract used by existing callers.
    return (k = cache.k, tmp_cache = cache.tmp_cache)
end
