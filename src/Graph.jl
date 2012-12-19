
module Graph
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<, Base.show
using Immutable

export Node, Value, Guard
# todo: don't export all of those?
export Arg, argsym, TupleRef, Bind, Egal, Isa, Never, never, Always, always
export typeguard
export Pattern, make_pattern, nullpat


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
type Always <: Guard; end
const always = Always()

typeguard(arg::Value, ::Type{Any}) = always
typeguard(arg::Value, ::Type{None}) = never
typeguard(arg::Value, typ) = Isa(arg, typ)

depsof(node::Union(Arg,Never)) = []
depsof(node::Union(TupleRef, Bind, Egal, Isa)) = [node.arg,]


(&)(e::Egal, f::Egal)= (@assert e.arg===f.arg; e.value===f.value ?   e : never)
(&)(e::Egal, t::Isa) = (@assert e.arg===t.arg; isa(e.value, t.typ) ? e : never)
(&)(t::Isa, e::Egal) = e & t
function (&)(s::Isa, t::Isa) 
    @assert s.arg===t.arg
    typeguard(s.arg, tintersect(s.typ, t.typ))
end


# ---- Pattern ----------------------------------------------------------------

type Pattern
    guards::Dict{Node,Guard}
    bindings::Set{Bind}
end

const nullpat = Pattern((Node=>Guard)[argnode => never], Set{Bind}())

function make_pattern(nodes::Node...)
    gs, bs = Dict{Node,Guard}(), Set{Bind}()
    for node in nodes
        if node === never; return nullpat; end
        if node === always; continue; end

        if isa(node, Bind); add(bs, node)
        else
            arg = node.arg
            new_g = gs[arg] = has(gs, arg) ? (node & gs[arg]) : node
            if new_g === never; return nullpat; end
        end
    end
    Pattern(gs, bs)
end

(&)(p::Pattern, q::Pattern) = make_pattern(
    values(p.guards)..., values(q.guards)..., p.bindings..., q.bindings...)
isequal(p::Pattern, q::Pattern) = isequal(p.guards, q.guards)

>=(p::Pattern, q::Pattern) = (p & q) == q
>(p::Pattern, q::Pattern)  = (p >= q) && (p != q)

<=(p::Pattern, q::Pattern) = q >= p
<(p::Pattern, q::Pattern)  = q >  p


function adduser(users::Dict, user::Node)
    for dep in depsof(user)
        if !has(users, dep)
            adduser(users, dep)
            users[dep] = Set{Node}()
        end        
        add(users[dep], user)
    end    
end

function show(io::IO, p::Pattern)
    if p === nullpat; print(io, "nullpat"); return; end
    
    users = Dict{Value, Set{Node}}()
    for b in p.bindings;       adduser(users, b); end
    for g in values(p.guards); adduser(users, g); end

    showpat(io, users, argnode)
end

nodekey(node::Bind) = (1,string(node.name))
nodekey(node::TupleRef) = (2,node.index)
nodekey(node::Union(Egal,Isa)) = (3,0)

cmp(x::Node,y::Node) = nodekey(x) < nodekey(y)

function showpat(io::IO, users::Dict, node::Value)
    if !has(users, node)
        print("::Any")
        return
    end

    # printing order: Bind, TupleRef, Egal, Isa
    us = sort(cmp, Node[users[node]...])
    k, n = 1, length(us)
    while k <= n
        u = us[k]
        if k > 1 && !isa(u, Isa); print(io, '~'); end
        if isa(u, Bind); print(io, u.name)
        elseif isa(u, Egal); print(io, u.value)
        elseif isa(u, Isa); print(io, "::", u.typ)
        elseif isa(u, TupleRef)
            print(io, '(')
            i = 0
            while k <= n && isa(us[k], TupleRef)
                if i==0; i=1; end
                u = us[k]
                @assert i <= u.index
                while i < u.index; print(io, ", "); i += 1; end
                i = u.index
                showpat(io, users, u)
                k += 1
            end
            if i == 1; print(io, ','); end
            print(io, ')')
            if k == n && isa(us[k], Isa) && us[k].typ == NTuple{i}; return; end
        else
            error("unknown node type")
        end
        k += 1
    end
end


end # module
