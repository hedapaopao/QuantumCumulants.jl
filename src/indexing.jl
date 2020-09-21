const IDX_TO_SYMS = Dict{SymbolicNumber,SymbolicUtils.Sym}()
const SYMS_TO_IDX = Dict{SymbolicUtils.Sym,SymbolicNumber}()

### Indices

struct Index{T<:Int,S,L,U} <: SymbolicNumber{T}
    name::S
    lower::L
    upper::U
    function Index{T,S,L,U}(name::S,lower::L,upper::U) where {T<:Int,S,L,U}
        idx = new(name,lower,upper)
        if !haskey(IDX_TO_SYMS, idx)
            sym = SymbolicUtils.Sym{Index}(gensym(:Index))
            IDX_TO_SYMS[idx] = sym
            SYMS_TO_IDX[sym] = idx
        end
        return idx
    end
end
Index{T}(name::S,lower::L,upper::U) where {T,S,L,U} = Index{T,S,L,U}(name,lower,upper)
Index(name,lower,upper) = Index{Int}(name,lower,upper)
_to_symbolic(idx::Index) = IDX_TO_SYMS[idx]
_to_qumulants(t::SymbolicUtils.Sym{T}) where T<:Index = SYMS_TO_IDX[t]

Base.hash(i::Index, h::UInt) = hash(i.upper, hash(i.lower, hash(i.name, h)))
Base.isless(i::Index, j::Index) = isless(hash(j), hash(i))
Base.isequal(i::Index, j::Index) = isequal(hash(j), hash(i))


### Indexed operators

for Tname in [:Destroy,:Create]
    Name = Symbol(:Indexed,Tname)
    @eval struct $(Name){H<:HilbertSpace,S,A,IND} <: BasicOperator
        hilbert::H
        name::S
        aon::A
        index::IND
        function $(Name){H,S,A,IND}(hilbert::H,name::S,aon::A,index::IND) where {H,S,A,IND}
            @assert has_hilbert(FockSpace,hilbert,aon)
            op = new(hilbert,name,aon,index)
            if !haskey(OPERATORS_TO_SYMS, op)
                sym = SymbolicUtils.Sym{$(Name)}(gensym(nameof($Name)))
                OPERATORS_TO_SYMS[op] = sym
                SYMS_TO_OPERATORS[sym] = op
            end
            return op
        end
    end
    @eval $(Name)(hilbert::H,name::S,aon::A,index::IND) where {H,S,A,IND} = $(Name){H,S,A,IND}(hilbert,name,aon,index)
    @eval Base.getindex(a::$Tname,i::Index) = $(Name)(a.hilbert,a.name,a.aon,i)
end
Base.adjoint(a::IndexedDestroy) = IndexedCreate(a.hilbert,a.name,a.aon,a.index)
Base.adjoint(a::IndexedCreate) = IndexedDestroy(a.hilbert,a.name,a.aon,a.index)

struct IndexedTransition{H,S,I,A,IND} <: BasicOperator
    hilbert::H
    name::S
    i::I
    j::I
    aon::A
    index::IND
    function IndexedTransition{H,S,I,A,IND}(hilbert::H,name::S,i::I,j::I,aon::A,index::IND) where {H,S,I,A,IND}
        @assert has_hilbert(NLevelSpace,hilbert,aon)
        @assert i∈levels(hilbert,aon) && j∈levels(hilbert,aon)
        op = new(hilbert,name,i,j,aon,index)
        if !haskey(OPERATORS_TO_SYMS, op)
            sym = SymbolicUtils.Sym{IndexedTransition}(gensym(:IndexedTransition))
            OPERATORS_TO_SYMS[op] = sym
            SYMS_TO_OPERATORS[sym] = op
        end
        return op
    end
end
IndexedTransition(hilbert::H,name::S,i::I,j::I,aon::A,index::IND) where {H,S,I,A,IND} = IndexedTransition{H,S,I,A,IND}(hilbert,name,i,j,aon,index)
Base.getindex(s::Transition,k::Index) = IndexedTransition(s.hilbert,s.name,s.i,s.j,s.aon,k)
Base.:(==)(t1::IndexedTransition,t2::IndexedTransition) = (t1.hilbert==t2.hilbert && t1.name==t2.name && t1.i==t2.i && t1.j==t2.j && isequal(t1.index,t2.index))
nip(args...) = OperatorTerm(nip, [args...])
nip(args::Vector) = OperatorTerm(nip, args)

for T in [:Destroy,:Create,:Transition]
    Name = Symbol(:Indexed,T)
    @eval get_index(a::$Name) = a.index
end

### Simplification functions
function commute_bosonic_idx(a::SymbolicUtils.Symbolic,b::SymbolicUtils.Symbolic)
    return _to_symbolic(commute_bosonic_idx(_to_qumulants(a), _to_qumulants(b)))
end
function commute_bosonic_idx(a,b)
    δ = (a.index == b.index)
    return δ + b*a
end

#σi*σj
function merge_idx_transitions(σ1::SymbolicUtils.Sym,σ2::SymbolicUtils.Sym)
    op = merge_idx_transitions(_to_qumulants(σ1), _to_qumulants(σ2))
    return _to_symbolic(op)
end
function merge_idx_transitions(σ1, σ2)
    i = σ1.index
    j = σ2.index
    δ = i==j
    σ3 = merge_transitions(σ1,σ2)
    return δ*σ3[i] + !(δ)*nip(σ1,σ2)
end

#nip*σ
function merge_nip_idx_transition(nip_::SymbolicUtils.Symbolic,σ::SymbolicUtils.Symbolic)
    p = merge_nip_idx_transition(_to_qumulants(nip_), _to_qumulants(σ))
    return _to_symbolic(p)
end
function merge_nip_idx_transition(nip_::OperatorTerm, σ::IndexedTransition)
    nip_σs = copy.(nip_.arguments)
    nip_idxs = find_index(nip_)
    if σ.index in nip_idxs
        it_σ = findfirst(x->isequal(x.index,σ.index), nip_σs)
        σ_new = merge_transitions(nip_σs[it_σ], σ)
        if iszero(σ_new)
            return 0
        else
            nip_σs[it_σ] = σ_new[σ.index]
            return nip(nip_σs)
        end
    else #σ.index not in nip_idxs
        all_summands = []
        δs = Number[]
        for itσ=1:length(nip_σs)
            σ_new = merge_transitions(nip_σs[itσ], σ)
            δ_ = (σ.index==nip_σs[itσ].index)
            push!(δs, !(δ_))
            if !iszero(σ_new)
                nip_σs_new = copy(nip_σs)
                nip_σs_new[itσ] = σ_new[σ.index]
                nip_σ_new = δ_*nip(nip_σs_new)
                push!(all_summands, nip_σ_new)
            end
        end
        push!(all_summands, *(δs...)*nip([nip_σs...,σ]))
        return sum(all_summands)
    end
end

#σ*nip
function merge_idx_transition_nip(σ::SymbolicUtils.Symbolic,nip_::SymbolicUtils.Symbolic)
    p = merge_idx_transition_nip( _to_qumulants(σ),_to_qumulants(nip_))
    return _to_symbolic(p)
end
function merge_idx_transition_nip(σ, nip_)
    nip_σs = copy(nip_.arguments)
    nip_idxs = find_index(nip_)
    if σ.index in nip_idxs
        it_σ = findfirst(x->isequal(x.index,σ.index), nip_σs)
        σ_new = merge_transitions(σ, nip_σs[it_σ])
        if iszero(σ_new)
            return 0
        else
            nip_σs[it_σ] = σ_new[σ.index]
            return nip(nip_σs)
        end
    else #σ.index not in nip_idxs
        all_summands = []
        δs = Number[]
        for itσ=1:length(nip_σs)
            σ_new = merge_transitions(σ,nip_σs[itσ])
            δ_ = (σ.index==nip_σs[itσ].index)
            push!(δs, !(δ_))
            if !iszero(σ_new)
                nip_σs_new = copy(nip_σs)
                nip_σs_new[itσ] = σ_new[σ.index]
                nip_σ_new = δ_*nip(nip_σs_new)
                push!(all_summands, nip_σ_new)
            end
        end
        push!(all_summands, *(δs...)*nip([σ,nip_σs...]))
        return sum(all_summands)
    end
end


### Parameters

struct IndexedParameter{T<:Number,S,I} <: SymbolicNumber{T}
    name::S
    idx::I
    function IndexedParameter{T,S,I}(name::S,idx::I) where {T,S,I}
        param_idx = new(name,idx)
        if !haskey(IDX_TO_SYMS, param_idx)
            sym = SymbolicUtils.Sym{IndexedParameter}(gensym(:IndexedParameter))
            IDX_TO_SYMS[param_idx] = sym
            SYMS_TO_IDX[sym] = param_idx
        end
        return param_idx
    end
end
IndexedParameter{T}(name::S,idx::I) where {T,S,I} = IndexedParameter{T,S,I}(name,idx)
IndexedParameter(name, idx) = IndexedParameter{Number}(name, idx)
_to_symbolic(param_idx::IndexedParameter) = IDX_TO_SYMS[param_idx]
_to_qumulants(t::SymbolicUtils.Sym{T}) where T<:IndexedParameter = SYMS_TO_IDX[t]

Base.isequal(p::T, q::T) where T<:IndexedParameter = (p.name==q.name && isequal(p.idx,q.idx))
Base.hash(p::IndexedParameter{T}, h::UInt) where T = hash(p.name, hash(p.idx, hash(T, h)))

# Methods
Base.conj(p::IndexedParameter{<:Real}) = p


struct IndexedOne{T,I,A} <: SymbolicNumber{T}
    idx::I
    aon::A
    function IndexedOne{T,I,A}(idx::I,aon::A) where {T,I,A}
        one_idx = new(idx,aon)
        if !haskey(IDX_TO_SYMS, one_idx)
            sym = SymbolicUtils.Sym{IndexedParameter}(gensym(:IndexedOne))
            IDX_TO_SYMS[one_idx] = sym
            SYMS_TO_IDX[sym] = one_idx
        end
        return one_idx
    end
end
IndexedOne{T}(idx::I,aon::A) where {T,I,A} = IndexedOne{T,I,A}(idx,aon)
IndexedOne(idx,aon) = IndexedOne{Int}(idx,aon)

find_index(s::SymbolicUtils.Symbolic) = _to_symbolic.(find_index(_to_qumulants(s)))
function find_index(t::OperatorTerm)
    idx = Index[]
    for arg in t.arguments
        append!(idx, find_index(arg))
    end
    return idx
end
find_index(::Number) = Index[]
find_index(x::Union{IndexedTransition,IndexedCreate,IndexedDestroy,IndexedParameter,IndexedOne}) = [x.index]