using OrdinaryDiffEqDifferentiation
using Aqua

@testset "Aqua" begin
    Aqua.test_all(
        OrdinaryDiffEqDifferentiation
    )
end