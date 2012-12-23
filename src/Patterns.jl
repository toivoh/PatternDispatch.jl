
module Patterns
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<
using Immutable

export Node, Predicate, Guard, Result, Never, Always, never, always
export depsof
export Intension, intension, naught, anything
export encode, guardsof, depsof, resultof, subs
export Pattern


# ---- Node -------------------------------------------------------------------

abstract Node{T}
typealias Predicate Node{Bool}

type Never  <: Predicate; end
type Always <: Predicate; end
const never   = Never()
const always  = Always()

@immutable type Guard <: Node{None}
    pred::Predicate
end
type Result{T} <: Node{T}
    node::Node{T}
    nrefs::Int
    ex
    
    Result(node::Node{T}) = new(node, 1, nothing)
end
Result{T}(node::Node{T}) = Result{T}(node)

subs(d::Dict, node::Guard)    = Guard(   d[node.pred])

resultof(node::Result) = (@assert node.ex != nothing; node.ex)


# ---- Intension --------------------------------------------------------------
       
type Intension
    factors::Dict{Node,Predicate}
end

#const naught   = Intension((Node=>Predicate)[argnode => never])
const naught   = Intension((Node=>Predicate)[always => never])
const anything = Intension((Node=>Predicate)[])

guardsof(x::Intension) = values(x.factors)

depsof(node::Guard) = [node.pred]
depsof(i::Intension,node::Node) = depsof(node)

function intension(factors::Predicate...)
    gs = Dict{Node,Predicate}()
    for g in factors
        if g === never; return naught; end
        if g === always; continue; end

        new_g = gs[g.arg] = get(gs, g.arg, always) & g
        if new_g === never; return naught; end
    end
    Intension(gs)
end

(&)(x::Intension, y::Intension) = intension(guardsof(x)..., guardsof(y)...)
isequal(x::Intension, y::Intension) = isequal(x.factors, y.factors)

>=(x::Intension, y::Intension) = (x & y) == y
>( x::Intension, y::Intension) = (x >= y) && (x != y)
<=(x::Intension, y::Intension) = y >= x
<( x::Intension, y::Intension) = y >  x


# ---- Pattern ----------------------------------------------------------------

type Pattern
    intent::Intension
    bindings::Dict{Symbol,Node}
end
Pattern(intent::Intension) = Pattern(intent, Dict{Symbol,Node}())

function (&)(p::Pattern, q::Pattern)
    bindings = merge(p.bindings, q.bindings)
#    @assert length(bindings) == length(p.bindings)+length(q.bindings)
    Pattern(p.intent & q.intent, bindings)
end

end # module
