@inline function SciMLBase.get_tmp_cache(
        integrator,
        alg::Union{RadauIIA3, RadauIIA5, RadauIIA9, AdaptiveRadau, GaussLegendre},
        cache::OrdinaryDiffEqMutableCache
    )
    return (tmp = cache.tmp_cache.tmp, atmp = cache.tmp_cache.atmp,
            tmp_cache = cache.tmp_cache)
end
