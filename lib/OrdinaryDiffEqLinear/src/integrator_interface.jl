@inline function SciMLBase.get_tmp_cache(
        integrator,
        alg::LinearExponential,
        cache::OrdinaryDiffEqMutableCache
    )
    return (tmp = cache.tmp_cache.tmp, tmp_cache = cache.tmp_cache)
end
