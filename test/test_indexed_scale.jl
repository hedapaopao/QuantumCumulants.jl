using Test
using QuantumCumulants
using SymbolicUtils
using Symbolics

const qc = QuantumCumulants

@testset "indexed_scale" begin

#test a system, where scaling is done individually per hilbertspace

@cnumbers N N2 Δ g κ Γ R ν M

hc = FockSpace(:cavity)
ha = NLevelSpace(:atom,2)

h = hc ⊗ ha

k = Index(h,:k,N,ha)
l = Index(h,:l,N,ha)

m = Index(h,:m,N2,hc)
n = Index(h,:n,N2,hc)

order = 2

σ(i,j,k) = IndexedOperator(Transition(h,:σ,i,j),k)
ai(k) = IndexedOperator(Destroy(h,:a),k)

H_2 = -Δ*∑(ai(m)'ai(m),m) + g*(∑(Σ(ai(m)'*σ(1,2,k),k),m) + ∑(Σ(ai(m)*σ(2,1,k),k),m))

J_2 = [ai(m),σ(1,2,k),σ(2,1,k),σ(2,2,k)]
rates_2 = [κ, Γ, R, ν]
ops_2 = [ai(n)'*ai(n),σ(2,2,l)]
eqs_2 = meanfield(ops_2,H_2,J_2;rates=rates_2,order=order)

q = Index(h,:q,N,ha)
r = Index(h,:r,N2,hc)

extra_indices = [q,r]

eqs_com = qc.complete(eqs_2;extra_indices=extra_indices);
eqs_com2 = qc.complete(eqs_2);
@test length(eqs_com) == 15
@test length(eqs_com) == length(eqs_com2)

s_1 = scale(eqs_com; h=2)
s_2 = scale(eqs_com; h=1)

# @test length(s_1) == length(s_2)
@test !(s_1.equations == s_2.equations)
@test !(s_1.states == s_2.states)

@test sort(qc.get_indices_equations(s_1)) == sort([m,n,r])
@test sort(qc.get_indices_equations(s_2)) == sort([k,l,q])

s1 = scale(eqs_com; h=[1,2])
s2 = scale(eqs_com)

s1_ = scale(eqs_com; h=[hc])
s2_ = scale(eqs_com; h=[1])

@test s1_.equations == s2_.equations


se = scale(eqs_com;h=[1])
se2 = qc.evaluate(se;h=[2],limits=(N=>2))

es = qc.evaluate(eqs_com;h=[2],limits=(N=>2))
es2 = scale(es;h=[1])

@test length(se2.equations) == length(es2.equations)
@test isequal(se2.equations[1],es2.equations[1])

@test length(s1) == length(s2)
@test s1.equations == s2.equations

avg = average(σ(2,2,k))
c_avg = conj(avg)

@test operation(qc.inorder!(c_avg)) == conj
@test operation(qc.inorder!(avg)) == qc.sym_average

@test operation(qc.insert_index(avg,k,1)) == qc.sym_average
@test operation(qc.insert_index(c_avg,k,1)) == conj

@test qc.get_indices_equations(s1) == []

@test s1.states == s2.states

@test isequal(scale(∑(average(σ(2,2,k)),k)), N*average(σ(2,2,1)))
@test isequal(scale(∑(average(ai(m)),m)), N2*average(ai(1)))
@test isequal(scale(average(∑(σ(2,1,k)*σ(1,2,l),k))), (N-1)*average(σ(2,1,1)*σ(1,2,2)) + average(σ(2,2,1)))


hc_ = FockSpace(:cavity) 
ha_ = NLevelSpace(:atom, 3)
h_ = hc_ ⊗ ha_
i2 = Index(h_,:i,N,ha_);
j2 = Index(h_,:j,N,ha_);

σ2(i,j,k) = IndexedOperator(Transition(h_,:σ,i,j),k)

Sz_(i) = ∑(σ2(2,2,i) - σ2(3,3,i),i)
Sz2 = average(Sz_(i2)*Sz_(j2))

@test isequal(scale(Sz2),average(N*average(σ2(3,3,1)) + N*σ2(2,2,1)) + (-1+N)^2*average(σ2(2,2,1)*σ2(2,2,2)) +
    (-1+N)^2*average(σ2(3,3,1)*σ2(3,3,2)) -2*(-1+N)^2*average(σ2(3,3,1)*σ2(2,2,2)))

end