@muladd function _ode_interpolant(
        Θ, dt, y₀, y₁, k, cache::Union{RadauIIA3ConstantCache, RadauIIA3Cache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; c1) = cache.tab
    z1 = k[3]
    z2 = k[4]
    #(0,0), (c1, z1), (1,z2)
    l1 = (Θ - 0) * (Θ - 1) / ((c1 - 0) * (c1 - 1))
    l2 = (Θ - 0) * (Θ - c1) / ((1 - 0) * (1 - c1))
    @.. y₀ + z1 * l1 + z2 * l2
end

@muladd function _ode_interpolant!(
        out, Θ, dt, y₀, y₁, k, cache::Union{RadauIIA3ConstantCache, RadauIIA3Cache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; c1) = cache.tab
    z1 = k[3]
    z2 = k[4]
    #(0,0), (c1, z1), (1,z2)
    l1 = (Θ - 0) * (Θ - 1) / ((c1 - 0) * (c1 - 1))
    l2 = (Θ - 0) * (Θ - c1) / ((1 - 0) * (1 - c1))
    @.. out = y₀ + z1 * l1 + z2 * l2
end

@muladd function _ode_interpolant(
        Θ, dt, y₀, y₁, k, cache::Union{RadauIIA5ConstantCache, RadauIIA5Cache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; c1, c2) = cache.tab
    z1 = k[3]
    z2 = k[4]
    z3 = k[5]

    l1 = (Θ - 0) * (Θ - c2) * (Θ - 1) / ((c1 - 0) * (c1 - c2) * (c1 - 1))
    l2 = (Θ - 0) * (Θ - c1) * (Θ - 1) / ((c2 - 0) * (c2 - c1) * (c2 - 1))
    l3 = (Θ - 0) * (Θ - c1) * (Θ - c2) / ((1 - 0) * (1 - c1) * (1 - c2))
    #l4 = 0 * (Θ - c1) * (Θ - c2) * (Θ - 1) / ((0 - c1) * (0 - c2) * (0 - 1))
    @.. y₀ + z1 * l1 + z2 * l2 + z3 * l3
end

@muladd function _ode_interpolant!(
        out, Θ, dt, y₀, y₁, k, cache::Union{RadauIIA5ConstantCache, RadauIIA5Cache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; c1, c2) = cache.tab
    z1 = k[3]
    z2 = k[4]
    z3 = k[5]

    l1 = (Θ - 0) * (Θ - c2) * (Θ - 1) / ((c1 - 0) * (c1 - c2) * (c1 - 1))
    l2 = (Θ - 0) * (Θ - c1) * (Θ - 1) / ((c2 - 0) * (c2 - c1) * (c2 - 1))
    l3 = (Θ - 0) * (Θ - c1) * (Θ - c2) / ((1 - 0) * (1 - c1) * (1 - c2))
    #l4 = 0 * (Θ - c1) * (Θ - c2) * (Θ - 1) / ((0 - c1) * (0 - c2) * (0 - 1))
    @.. out = y₀ + z1 * l1 + z2 * l2 + z3 * l3
end

@muladd function _ode_interpolant(
        Θ, dt, y₀, y₁, k, cache::Union{RadauIIA9ConstantCache, RadauIIA9Cache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; c1, c2, c3, c4) = cache.tab

    z1 = k[3]
    z2 = k[4]
    z3 = k[5]
    z4 = k[6]
    z5 = k[7]

    l1 = (Θ - 0) * (Θ - c2) * (Θ - c3) * (Θ - c4) * (Θ - 1) / ((c1 - 0) * (c1 - c2) * (c1 - c3) * (c1 - c4) * (c1 - 1))
    l2 = (Θ - 0) * (Θ - c1) * (Θ - c3) * (Θ - c4) * (Θ - 1) / ((c2 - 0) * (c2 - c1) * (c2 - c3) * (c2 - c4) * (c2 - 1))
    l3 = (Θ - 0) * (Θ - c1) * (Θ - c2) * (Θ - c4) * (Θ - 1) / ((c3 - 0) * (c3 - c1) * (c3 - c2) * (c3 - c4) * (c3 - 1))
    l4 = (Θ - 0) * (Θ - c1) * (Θ - c2) * (Θ - c3) * (Θ - 1) / ((c4 - 0) * (c4 - c1) * (c4 - c2) * (c4 - c3) * (c4 - 1))
    l5 = (Θ - 0) * (Θ - c1) * (Θ - c2) * (Θ - c3) * (Θ - c4) / ((1 - 0) * (1 - c1) * (1 - c2) * (1 - c3) * (1 - c4))
    #l6 = 0 * (Θ - c1) * (Θ - c2) * (Θ - c3) * (Θ - c4) * (Θ - 1) / ((0 - c1) * (0 - c2) * (0 - c3) * (0 - c4) * (0 - 1))
    @.. y₀ + z1 * l1 + z2 * l2 + z3 * l3 + z4 * l4 + z5 * l5

end

@muladd function _ode_interpolant!(
        out, Θ, dt, y₀, y₁, k, cache::Union{RadauIIA9ConstantCache, RadauIIA9Cache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; c1, c2, c3, c4) = cache.tab

    z1 = k[3]
    z2 = k[4]
    z3 = k[5]
    z4 = k[6]
    z5 = k[7]

    l1 = (Θ - 0) * (Θ - c2) * (Θ - c3) * (Θ - c4) * (Θ - 1) / ((c1 - 0) * (c1 - c2) * (c1 - c3) * (c1 - c4) * (c1 - 1))
    l2 = (Θ - 0) * (Θ - c1) * (Θ - c3) * (Θ - c4) * (Θ - 1) / ((c2 - 0) * (c2 - c1) * (c2 - c3) * (c2 - c4) * (c2 - 1))
    l3 = (Θ - 0) * (Θ - c1) * (Θ - c2) * (Θ - c4) * (Θ - 1) / ((c3 - 0) * (c3 - c1) * (c3 - c2) * (c3 - c4) * (c3 - 1))
    l4 = (Θ - 0) * (Θ - c1) * (Θ - c2) * (Θ - c3) * (Θ - 1) / ((c4 - 0) * (c4 - c1) * (c4 - c2) * (c4 - c3) * (c4 - 1))
    l5 = (Θ - 0) * (Θ - c1) * (Θ - c2) * (Θ - c3) * (Θ - c4) / ((1 - 0) * (1 - c1) * (1 - c2) * (1 - c3) * (1 - c4))

    @.. out = y₀ + z1 * l1 + z2 * l2 + z3 * l3 + z4 * l4 + z5 * l5

end

@muladd function _ode_interpolant(
        Θ, dt, y₀, y₁, k, cache::Union{AdaptiveRadauConstantCache, AdaptiveRadauCache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; num_stages, index) = cache
    (; c) = cache.tabs[index]

    for i in 1:num_stages
        tmp = k[i + 2]
        for j in 1:num_stages
            if j != i
                tmp *= (Θ - c[j]) / (c[i] - c[j])
            end
        end
        y₀ = @.. y₀ + tmp * Θ / c[i]
    end
    y₀
end

@muladd function _ode_interpolant!(
        out, Θ, dt, y₀, y₁, k, cache::Union{AdaptiveRadauConstantCache, AdaptiveRadauCache},
        idxs::Nothing, T::Type{Val{0}}, differential_vars
    )
    (; num_stages, index) = cache
    (; c) = cache.tabs[index]

    tmp = similar(out)
    out .= y₀
    for i in 1:num_stages
        tmp .= k[i + 2]
        for j in 1:num_stages
            if j != i
                tmp .*= (Θ - c[j]) / (c[i] - c[j])
            end
        end
        @.. out += tmp * Θ / c[i]
    end
    out
end

# Derivatives, and values with `idxs`, use the generic Hermite interpolant. Radau stores
# the stage increments `zⱼ` in `k[3:end]` and the last node is `cₛ = 1`, so the end state
# of the completed step is `y₀ + zₛ` (`perform_step!` computes `u = uprev + zₛ`). The
# Hermite interpolant gets this end state in place of `y₁`, so it does not read `y₁`
# (see `OrdinaryDiffEqCore.uses_cut_curve`). For a normal step the result is unchanged, to
# round-off.
#
# The Hermite kernels are pointwise. So `idxs` is applied first (as views, or as scalars
# for one index), and the kernels run on the selection. In place, `out` holds the end
# state and is passed as `y₁`: each element reads `y₁[i]` before it writes `out[i]`. Thus
# the end state needs no temporary array.
#
# AdaptiveRadau changes the number of stages between steps, and `k` does not record it,
# so `zₛ` of a step is not known. AdaptiveRadau keeps the generic Hermite interpolant.
const RADAU_CACHES = Union{
    RadauIIA3ConstantCache, RadauIIA3Cache, RadauIIA5ConstantCache, RadauIIA5Cache,
    RadauIIA9ConstantCache, RadauIIA9Cache,
}

_radau_last(::Union{RadauIIA3ConstantCache, RadauIIA3Cache}) = 4
_radau_last(::Union{RadauIIA5ConstantCache, RadauIIA5Cache}) = 5
_radau_last(::Union{RadauIIA9ConstantCache, RadauIIA9Cache}) = 7

@inline _radau_select(x, ::Nothing) = x
@inline _radau_select(x, idxs::Number) = x[idxs]
@inline _radau_select(x, idxs) = @view x[idxs]

@inline _radau_view(x, ::Nothing) = x
@inline _radau_view(x, idxs) = @view x[idxs]

function _ode_interpolant(
        Θ, dt, y₀, y₁, k, cache::RADAU_CACHES, idxs, T::Type{Val{D}}, differential_vars
    ) where {D}
    D > 3 && throw(OrdinaryDiffEqCore.DerivativeOrderNotPossibleError())
    # Before the first step `k` is empty.
    length(k) < _radau_last(cache) &&
        return OrdinaryDiffEqCore.linear_interpolant(Θ, dt, y₀, y₁, idxs, T)
    dv = OrdinaryDiffEqCore.interpolation_differential_vars(differential_vars, y₀, idxs)
    Y₀ = _radau_select(y₀, idxs)
    Z = _radau_select(k[_radau_last(cache)], idxs)
    K = (_radau_select(k[1], idxs), _radau_select(k[2], idxs))
    Y₁ = Y₀ isa Number ? Y₀ + Z : Y₀ .+ Z
    mutable = !(Y₀ isa Number) && cache isa OrdinaryDiffEqMutableCache
    return OrdinaryDiffEqCore.hermite_interpolant(
        Θ, dt, Y₀, Y₁, K, Val{mutable}, nothing, T, dv
    )
end

function _ode_interpolant!(
        out, Θ, dt, y₀, y₁, k, cache::RADAU_CACHES, idxs, T::Type{Val{D}}, differential_vars
    ) where {D}
    D > 3 && throw(OrdinaryDiffEqCore.DerivativeOrderNotPossibleError())
    length(k) < _radau_last(cache) &&
        return OrdinaryDiffEqCore.linear_interpolant!(out, Θ, dt, y₀, y₁, idxs, T)
    dv = OrdinaryDiffEqCore.interpolation_differential_vars(differential_vars, y₀, idxs)
    Y₀ = _radau_view(y₀, idxs)
    Z = _radau_view(k[_radau_last(cache)], idxs)
    K = (_radau_view(k[1], idxs), _radau_view(k[2], idxs))
    # `out` of a derivative can have a different element type (for example units of u/t).
    if eltype(out) === promote_type(eltype(Y₀), eltype(Z))
        @.. broadcast = false out = Y₀ + Z
        Y₁ = out
    else
        Y₁ = Y₀ .+ Z
    end
    return OrdinaryDiffEqCore.hermite_interpolant!(out, Θ, dt, Y₀, Y₁, K, nothing, T, dv)
end
