using Qumulants
using Test

n = Parameter{Int}(:n)
i = Index(:i,n)
j = Index(:j,n)
k = Index(:k,n)

h = FockSpace(:fock)
a = Destroy(h,:a)


@test isequal(simplify_operators(a[i]*a[j]'), (i==j) + a[j]'*a[i])
@test isequal(simplify_operators(a[i]*a[i]'), true+a[i]'*a[i])


# Nlevel
h = NLevelSpace(:nlevel,2)
σ(i,j) = Transition(h,:σ,i,j)
n = (i!=j)*Qumulants.nip(σ(2,1)[i],σ(1,2)[j])
n2 = (j!=k)*Qumulants.nip(σ(2,1)[j],σ(1,2)[k])

@test simplify_operators(σ(2,1)[i]*σ(1,2)[i]) == σ(2,2)[i]
@test simplify_operators(σ(2,1)[i]*σ(1,2)[j]) == n + (i==j)*σ(2,2)[i]
@test simplify_operators(n*σ(2,1)[i])==simplify_operators(n*σ(1,2)[j])==0
@test simplify_operators(n*σ(1,2)[i])==(i!=j)*Qumulants.nip(σ(1,2)[j],σ(2,2)[i])

@test simplify_operators(n*σ(2,1)[i])==simplify_operators(n*σ(1,2)[j])==0
@test simplify_operators(n*σ(1,2)[i])==(i!=j)*Qumulants.nip(σ(1,2)[j],σ(2,2)[i])

# Test Tavis-Cummings
hf = FockSpace(:field)
ha = NLevelSpace(:atom,2)
h = hf⊗ha
a = Destroy(h,:a)
σ(i,j) = Transition(h,:σ,i,j)
@parameters g
H = Sum(g[i]*(a'*σ(1,2)[i] + a*σ(2,1)[i]), i)

n = (j!=k)*Qumulants.nip(σ(2,1)[k],σ(1,2)[j])
ops = [a,σ(1,2)[j],σ(2,2)[j],a'*σ(1,2)[j],n]
he = heisenberg(ops,H)

# Test many-atom laser
hf = FockSpace(:field)
ha = NLevelSpace(:atom,2)
h = hf⊗ha
a = Destroy(h,:a)
σ(i,j) = Transition(h,:σ,i,j)
@parameters g κ γ ν Δ
H = Sum(Δ[i]*σ(2,2)[i], i) + Sum(g[i]*(a'*σ(1,2)[i] + a*σ(2,1)[i]), i)

n = (j!=k)*Qumulants.nip(σ(2,1)[k],σ(1,2)[j])
ops = [a,σ(1,2)[j],σ(2,2)[j],a'*σ(1,2)[j],n]
J = [a, σ(1,2)[i], σ(2,1)[i]]
rates = [2κ, γ[i], ν[i]]
he = heisenberg(ops,H,J;rates=rates)


# Test dipole-dipole
h = NLevelSpace(:atom,2)
σ(i,j) = Transition(h,:σ,i,j)
@parameters ω Ω Γ
n = (i!=j)*Qumulants.nip(σ(2,1)[i],σ(1,2)[j])
H = Sum(ω[i]*σ(2,2)[i], i) + Sum(Ω[i,j]*n, i, j)
J = [σ(1,2)[i]]
rates = [Γ[i,j]]
ops = [σ(1,2)[k], σ(2,2)[k]]
he = heisenberg(ops,H,J;rates=rates)

he_avg1 = average(he,1)
@test isempty(find_missing(he_avg1))

n = Parameter{Int}(:n)
Nn = 4
ps = (ω,Ω,Γ)
meta_f = build_ode(he_avg1,ps;idx_borders=[n=>Nn],check_bounds=true)
f = Meta.eval(meta_f)

using OrdinaryDiffEq, LinearAlgebra
u0 = zeros(ComplexF64, 2Nn)
u0[Nn+1:end] .= 1.0
Γmat = diagm(0=>ones(Nn))
Ωmat = zeros(Nn,Nn)
for i=1:Nn-1
    Ωmat[i, i+1] = Ωmat[i+1,i] = 0.25
end
ωn = ones(Nn)
p0 = (ωn,Ωmat,Γmat)
prob = ODEProblem(f,u0,(0.0,10.0),p0)
sol = solve(prob,Tsit5())

using PyPlot
plot(sol.t, real.(getindex.(sol.u, 2Nn)))

# Second order
J = [σ(1,2)[i]]
rates = [Γ[i,j]]
m = Index(:m,n)
ops = [σ(1,2)[k], σ(2,2)[k], (k!=m)*Qumulants.nip(σ(2,1)[k],σ(1,2)[m]), (k!=m)*Qumulants.nip(σ(2,2)[k],σ(1,2)[m]),
    (k!=m)*Qumulants.nip(σ(1,2)[k],σ(2,2)[m]), (k!=m)*Qumulants.nip(σ(2,2)[k],σ(2,2)[m])]
he = heisenberg(ops,H,J;rates=rates)
he_avg2 = average(he,2)

meta_f = build_ode(he_avg2, ps; idx_borders=[n=>Nn])
