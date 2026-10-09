function SciMLBase.interp_summary(
        ::Type{cacheType},
        dense::Bool
    ) where {
        cacheType <:
        Union{
            Tsit5Cache, Tsit5ConstantCache,
        },
    }
    return dense ? "specialized 4th order \"free\" interpolation" : "1st order linear"
end

# The interpolant and the lazy stages do not read `y₁`, so a cut step keeps the curve of
# the completed step. See `OrdinaryDiffEqCore.uses_cut_curve`.
OrdinaryDiffEqCore.uses_cut_curve(::Union{
    Tsit5Cache, Tsit5ConstantCache,
}) = true
