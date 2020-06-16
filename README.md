# Qumulants.jl
**Qumulants.jl** is a package for the symbolic derivation of Heisenberg equations in Julia. Averages over the resulting equations can be automatically expanded in terms of cumulants to an arbitrary order. This procedure yields a system of symbolic *c*-number differential equations. Finally, these *c*-number equations can be mapped to a function which can be solved using [DifferentialEquations.jl](http://docs.juliadiffeq.org/latest/).

For the application of commutation relations and general simplification, **Qumulants.jl** uses [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl).


## Development status

[![Travis build status][travis-img]][travis-url]

**Qumulants.jl** is still at a very early stage of development. **Expect bugs!**


## Basic usage

The package can be installed with

```julia
|pkg> add https://github.com/david-pl/Qumulants.jl.git
```

The basic usage is probably best illustrated with a brief example. In the following, we solve a simple model for a single-atom laser.

We start by loading the package, defining some symbolic parameters and the photonic annihilation operator `a` as well as the atomic lowering operator `s`. This allows us to quickly write down the Hamiltonian and the collapse operators of the system with their corresponding decay rates.

```julia
using Qumulants

# Define parameters
@parameters Δ g γ κ ν

# Define hilbert space
hf = FockSpace(:cavity)
ha = NLevelSpace(:atom,(:g,:e))
h = hf ⊗ ha

# Define the fundamental operators
a = Destroy(h,:a)
s = Transition(h,:σ,:g,:e)

# Hamiltonian
H = Δ*a'*a + g*(a'*s + a*s')

# Collapse operators
J = [a,s,s']
rates = [κ,γ,ν]
```

Now, we define a list of operators of which we want to compute the Heisenberg equations. We will only consider products of two operators. This is because later we will compute the dynamics of the system up to second order.

```julia
# Derive a set of Heisenberg equations
ops = [a'*a,s'*s,a'*s]
he = heisenberg(ops,H,J;rates=rates)
```

The equations derived above are differential equations for operators. In order to convert them to *c*-number equations, we need to average over them. To obtain a closed set of equations, we expand higher-order products to second order.

```julia
# Average the above equations and expand to second order
he_avg = average(he,2)
```

The first-order contributions are always zero and can therefore be neglected. You can try adding `a` and `s` to the list of operators `ops` in order to see that yourself. Or, even more conveniently, you can use `complete(he_avg,H,J;rates=rates)`, which will automatically find all missing averages and compute the corresponding equations.

Here, though, we will proceed by finding the missing averages, and neglecting them as zero using the `substitute` function.

```julia
# Find the missing averages
p = (Δ, g, γ, κ, ν)
missed = find_missing(he_avg;ps=p)

# Substitute them as zero
subs = Dict(missed .=> 0)
he_nophase = simplify_constants(substitute(he_avg, subs))
```

Finally, we can generate Julia code from the above set of equations which can be solved directly using the [OrdinaryDiffEq](https://github.com/JuliaDiffEq/OrdinaryDiffEq.jl).

```julia
# Generate a Julia function that to solve numerically
f = generate_ode(he_nophase,p)

# Solve the system using the OrdinaryDiffEq package
using OrdinaryDiffEq
u0 = zeros(ComplexF64,length(ops))
p0 = (0, 1.5, 0.25, 1, 4)
prob = ODEProblem(f,u0,(0.0,10.0),p0)
sol = solve(prob,RK4())
```

The photon number of our laser and the excited state population of the atom are now stored in the first two fields of `sol.u`.


[travis-url]: https://travis-ci.org/david-pl/Qumulants.jl
[travis-img]: https://api.travis-ci.org/david-pl/Qumulants.jl.png?branch=master
