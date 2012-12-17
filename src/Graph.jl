
module Graph
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<
using Immutable

export Node, Value, Guard
export Arg, argsym, TupleRef, Bind, Egal, Isa, Never, never
export Pattern, make_pattern, nullpat, unbind


# ---- Node -------------------------------------------------------------------

abstract Node
abstract Value <: Node
abstract Guard <: Node

type Arg <: Value; end
const argnode = Arg()
const argsym  = gensym("arg")

@immutable type TupleRef <: Value;  arg::Value; index::Int;    end
@immutable type Bind     <: Node;   arg::Value; name::Symbol;  end
@immutable type Egal     <: Guard;  arg::Value; value;         end
@immutable type Isa      <: Guard;  arg::Value; typ;           end
type Never <: Guard; end
const never = Never()


(&)(e::Egal, f::Egal)= (@assert e.arg===f.arg; e.value===f.value ?   e : never)
(&)(e::Egal, t::Isa) = (@assert e.arg===t.arg; isa(e.value, t.typ) ? e : never)
(&)(t::Isa, e::Egal) = e & t
function (&)(s::Isa, t::Isa) 
    @assert s.arg===t.arg
    T = tintersect(s.typ, t.typ)
    T === None ? never : Isa(s.arg, T)
end


# ---- Pattern ----------------------------------------------------------------

type Pattern
#    guards::Vector{Node}
    guards::Dict{Node,Guard}
    bindings::Set{Bind}
end

const nullpat = Pattern((Node=>Guard)[argnode => never], Set{Bind}())

function make_pattern(nodes::Node...)
    gs, bs = Dict{Node,Guard}(), Set{Bind}()
    for node in nodes
        if isa(node, Never); return nullpat; end

        if isa(node, Bind); add(bs, node)
        else
            arg = node.arg
            new_g = gs[arg] = has(gs, arg) ? (node & gs[arg]) : node
            if new_g === never; return nullpat; end
        end
    end
    Pattern(gs, bs)
end

unbind(p::Pattern) = Pattern(p.guards, Set{Bind}())
(&)(p::Pattern, q::Pattern) = make_pattern(
    values(p.guards)..., values(q.guards)..., p.bindings..., q.bindings...)
function isequal(p::Pattern, q::Pattern)
    isequal(p.guards, q.guards) && isequal(p.bindings, q.bindings)
end

>=(p::Pattern, q::Pattern) = (p & q) == q
>(p::Pattern, q::Pattern)  = (p >= q) && (p != q)

<=(p::Pattern, q::Pattern) = q >= p
<(p::Pattern, q::Pattern)  = q >  p


end # module
