using OrdinaryDiffEq, Test
using OrdinaryDiffEqLowOrderRK, OrdinaryDiffEqHighOrderRK
using OrdinaryDiffEqSSPRK, OrdinaryDiffEqRosenbrock

function test_ode(u, p, t)
    return [p[1] - (1 - p[1]) * u[1]]
end

function test_ode(du, u, p, t)
    du[1] = p[1] - (1 - p[1]) * u[1]
    return nothing
end

test_solution(t) = t <= 5 ? t : 5.0 * exp(-(t - 5))

tspan = (0.0, 10.0)
testtimes = range(tspan[1], stop = tspan[2], length = 1001)
pullback_condition(u, t, i) = t - 5
pullback_affect!(i) = i.p[1] = abs(1 - i.p[1])
cb = ContinuousCallback(pullback_condition, pullback_affect!)

# DPRKN6 is left out because second order ODE
algs = [
    Tsit5, Rosenbrock23, DP5, DP8, SSPRK43, SSPRK432, OwrenZen3, SSPRK22, SSPRK33,
    OwrenZen4, OwrenZen5, Rosenbrock32, Rodas5, Rodas4, Rodas42, Rodas5P,
] ## Works for these
lazy_alg = [BS5, Vern6, Vern7, Vern8, Vern9]
bad_algs = []

nonstandard_interp_algs = union(algs, bad_algs, lazy_alg)

passed = fill(false, 2length(nonstandard_interp_algs))

cur_itr = 0
for inplace in [false, true], alg in algs
    global cur_itr
    prob = ODEProblem{inplace}(test_ode, [0.0], tspan, [1.0])
    sol = solve(prob, alg(); callback = cb, dt = 0.0013)
    pass = all(isapprox(sol(t)[1], test_solution(t); atol = 0.05) for t in testtimes)
    x = maximum(sol(t)[1] - test_solution(t) for t in testtimes)
    cur_itr += 1
    passed[cur_itr] = pass
end

for inplace in [false, true], alg in lazy_alg
    global cur_itr
    prob = ODEProblem{inplace}(test_ode, [0.0], tspan, [1.0])
    sol = solve(prob, alg(); callback = cb, dt = 0.0013)
    # The cut step keeps the stages of the completed step, including the lazy stages that
    # root finding built before the affect changed `p`. They were once dropped and rebuilt
    # after the solve with the changed `p`, so the lazy variants failed this test.
    lazy_pass = all(isapprox(sol(t)[1], test_solution(t); atol = 0.05) for t in testtimes)

    prob = ODEProblem{inplace}(test_ode, [0.0], tspan, [1.0])
    sol = solve(prob, alg(lazy = Val{false}()); callback = cb, dt = 0.0013)
    pass = all(isapprox(sol(t)[1], test_solution(t); atol = 0.05) for t in testtimes)

    cur_itr += 1
    passed[cur_itr] = pass && lazy_pass
end

any(.!(passed)) &&
    @warn("The following algorithms failed the continuous callback test: $(vcat(algs, algs, lazy_alg, lazy_alg)[.!(passed)])")
@test all(passed)

# A cut step keeps the stages of the completed step. These tests cover the cases where the
# saved solution or `get_du` cannot use that curve directly.
osc(u, p, t) = [u[2], -u[1]]
osc!(du, u, p, t) = (du[1] = u[2]; du[2] = -u[1]; nothing)

@testset "Cut in the first step with save_start = false" begin
    # The first saved interval has no left knot, so its derivative must not read `ts[0]`.
    cut_cb = ContinuousCallback((u, t, i) -> t - 0.05, i -> (i.u[2] = -i.u[2]))
    sol = solve(
        ODEProblem(osc, [1.0, 0.0], (0.0, 3.0)), Tsit5();
        save_start = false, dt = 0.1, callback = cut_cb
    )
    exact = [-sin(0.05), -cos(0.05)]
    @test sol(sol.t[1], Val{1}) ≈ exact atol = 1.0e-6
    @test sol([sol.t[1]], Val{1}).u[1] ≈ exact atol = 1.0e-6
    out = zeros(2)
    sol(out, sol.t[1], Val{1})
    @test out ≈ exact atol = 1.0e-6
end

@testset "get_du after a cut ($(nameof(f)))" for f in (osc, osc!)
    # Inside the affect, the event is inside the completed step. `get_du` must give f at
    # the event state, not the derivative of the interpolant.
    errs = Float64[]
    affect! = function (integ)
        exact = [integ.u[2], -integ.u[1]]
        push!(errs, maximum(abs, get_du(integ) - exact))
        du = similar(integ.u)
        get_du!(du, integ)
        push!(errs, maximum(abs, du - exact))
        integ.u[2] = -integ.u[2]
    end
    solve(
        ODEProblem(f, [1.0, 0.0], (0.0, 10.0)), Tsit5();
        reltol = 1.0e-9, abstol = 1.0e-9,
        callback = ContinuousCallback((u, t, i) -> u[1], affect!)
    )
    @test !isempty(errs)
    @test maximum(errs) <= 1.0e-12
end
