function SciMLBase.interp_summary(
        ::Type{cacheType},
        dense::Bool
    ) where {
        cacheType <:
        Union{DP8ConstantCache, DP8Cache},
    }
    return dense ? "specialized 7th order interpolation" : "1st order linear"
end

# The interpolant and the lazy stages do not read `y₁`, so a cut step keeps the curve of
# the completed step. See `OrdinaryDiffEqCore.uses_cut_curve`.
OrdinaryDiffEqCore.uses_cut_curve(::Union{
    DP8Cache, DP8ConstantCache,
}) = true
