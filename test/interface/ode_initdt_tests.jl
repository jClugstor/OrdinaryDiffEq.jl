using OrdinaryDiffEq, DiffEqDevTools, Test
using DiffEqProblemLibrary.ODEProblemLibrary: importodeproblems; importodeproblems()
import DiffEqProblemLibrary.ODEProblemLibrary: prob_ode_linear, prob_ode_2Dlinear

prob = prob_ode_linear
sol =solve(prob,Rosenbrock32())
dt₀ = sol.t[2]

prob = prob_ode_2Dlinear
sol =solve(prob,ExplicitRK(tableau=constructBogakiShampine3()))
dt₀ = sol.t[2]

@test  1e-7 < dt₀ < .1
@test_throws ErrorException sol = solve(prob,Euler())
#dt₀ = sol.t[2]

sol3 =solve(prob,ExplicitRK(tableau=constructDormandPrince8_64bit()))
dt₀ = sol3.t[2]

@test 1e-7 < dt₀ < .3

T = Float32
u0 = T.([1.0;0.0;0.0])

tspan = T.((0,100))
prob = remake(prob, u0=u0, tspan=tspan)
@test_nowarn solve(prob, Euler(); dt=T(0.0001))

tspan = T.((2000,2100))
prob = remake(prob, tspan=tspan)
@test_throws ArgumentError solve(prob, Euler(); dt=T(0.0001)) # Loops forever

function rober(du,u,p,t)
  y₁,y₂,y₃ = u
  k₁,k₂,k₃ = p
  du[1] = -k₁*y₁+k₃*y₂*y₃
  du[2] =  k₁*y₁-k₂*y₂^2-k₃*y₂*y₃
  du[3] =  k₂*y₂^2
  nothing
end
u0 = Float32[1.0,0.0,0.0]
tspan = (0f0, 1f5)
params = (4f-2,3f7,1f4)
prob = ODEProblem(rober,u0,tspan,params)
sol = solve(prob, Rosenbrock23())

# https://github.com/SciML/DifferentialEquations.jl/issues/743

using LinearAlgebra
function f(du, u, p, t)
    du[1] = -p[1]*u[1] + p[2]*u[2]*u[3]
    du[2] = p[1]*u[1] - p[2]*u[2]*u[3] - p[3]*u[2]*u[2]
    du[3] = u[1] + u[2] + u[3] - 1.
end
M = Diagonal([1,1,0])
p = [0.04, 10^4, 3e7]
u0 = [1.,0.,0.]
tspan = (0., 1e6)
prob = ODEProblem(ODEFunction(f, mass_matrix = M), u0, tspan, p)
sol = solve(prob, Rodas5())
@test sol.t[end] == 1e6
