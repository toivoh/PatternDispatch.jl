
module Patterns
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<, Base.==
using Immutable

export Node, Predicate, Atom, Guard, never, always
export depsof
export Intension, intension, naught, anything
export encode, predsof, depsof, subs, resultof
export Pattern, suffix_bindings


# ---- Node -------------------------------------------------------------------

abstract Node{T}
typealias Predicate Node{Bool}

@immutable type Atom{T} <: Node{T}
    value::T
end
Atom{T}(value::T) = Atom{T}(value)

depsof(node::Atom) = []

const never  = Atom(false)
const always = Atom(true)

@immutable type Guard <: Node{None}
    pred::Predicate
end
subs(d::Dict, node::Guard) = Guard(d[node.pred])

resultof(node::Node) = error("Undefined!")


# ---- Intension --------------------------------------------------------------
       
type Intension
    factors::Dict{Node,Predicate}
end

#const naught   = Intension((Node=>Predicate)[argnode => never])
const naught   = Intension((Node=>Predicate)[always => never])
const anything = Intension((Node=>Predicate)[])

predsof(x::Intension) = values(x.factors)

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

(&)(x::Intension, y::Intension) = intension(predsof(x)..., predsof(y)...)
isequal(x::Intension, y::Intension) = isequal(x.factors, y.factors)

# works around that type equivalence is weaker than isequal
# works together with (&)(::Isa, ::Isa)
>=(x::Intension, y::Intension) = isequal(x & y, y)     # (x & y) == y
>( x::Intension, y::Intension) = (x >= y) && !(y >= x) # (x >= y) && (x != y)
==(x::Intension, y::Intension) = (x >= y) && (y >= x)
<=(x::Intension, y::Intension) = y >= x
<( x::Intension, y::Intension) = y >  x



# ---- Pattern ----------------------------------------------------------------

type Pattern
    intent::Intension
    bindings::Dict{Symbol,Node}
    rev_bindings::Dict{Node,Symbol}

    function Pattern(intent::Intension, bindings::Dict{Symbol,Node})
        rev = (Node=>Symbol)[node => name for (name,node) in bindings]
        new(intent, bindings, rev)
    end
end
Pattern(intent::Intension) = Pattern(intent, Dict{Symbol,Node}())

function (&)(p::Pattern, q::Pattern)
    bindings = merge(p.bindings, q.bindings)
    @assert length(bindings) == length(p.bindings)+length(q.bindings)
    Pattern(p.intent & q.intent, bindings)
end

function suffix_bindings(p::Pattern, suffix::String)
    Pattern(p.intent, (Symbol=>Node)[symbol(string(name, suffix)) => node
                                     for (name,node) in p.bindings])
end

end # module
