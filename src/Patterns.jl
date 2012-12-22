
module Patterns
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<, Base.show
using Immutable, Toivo
export Node, Predicate, Guard, Result
export argsym, argnode, never, always, tupref, egalpred, typepred, subs
export Intension, intension, naught, anything
export encode, guardsof, depsof
export Pattern


# ---- Node -------------------------------------------------------------------

abstract Node{T}
typealias Predicate Node{Bool}

type Arg    <: Node{Any}; end
type Never  <: Predicate; end
type Always <: Predicate; end
const argnode = Arg()
const argsym  = gensym("arg")
const never   = Never()
const always  = Always()

@immutable type TupleRef <: Node{Any};  arg::Node; index::Int;  end
@immutable type Egal     <: Predicate;  arg::Node; value;       end
@immutable type Isa      <: Predicate;  arg::Node; typ;         end

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

tupref(  arg::Node, index::Int) = TupleRef(arg, index)
egalpred(arg::Node, value)      = Egal(arg, value)

typepred(arg::Node, ::Type{Any})  = always
typepred(arg::Node, ::Type{None}) = never
typepred(arg::Node, typ) = Isa(arg, typ)

subs(d::Dict, node::Union(Arg, Never, Always)) = node
subs(d::Dict, node::TupleRef) = TupleRef(d[node.arg], node.index)
subs(d::Dict, node::Egal)     = Egal(    d[node.arg], node.value)
subs(d::Dict, node::Isa)      = Isa(     d[node.arg], node.typ)
subs(d::Dict, node::Guard)    = Guard(   d[node.pred])

resultof(node::Result) = (@assert node.ex != nothing; node.ex)
encode(v::Arg)      = argsym
encode(v::TupleRef) = :( $(resultof(v.arg))[$(v.index)] )
encode(g::Egal)     = :(is( $(resultof(g.arg)), $(quot(g.value))))
encode(g::Isa)      = :(isa($(resultof(g.arg)), $(quot(g.typ  ))))

# (&)(::Never,     ::Never) = never
# (&)(::Predicate, ::Never) = never
# (&)(::Never, ::Predicate) = never
(&)(::Always,        ::Always) = allways
(&)(node::Predicate, ::Always) = node
(&)(::Always, node::Predicate) = node

samearg(n::Node, m::Node) = @assert n.arg===m.arg
(&)(e::Egal, f::Egal) = (samearg(e, f); e.value === f.value ? e : never)
(&)(e::Egal, t::Isa)  = (samearg(e, t); isa(e.value, t.typ) ? e : never)
(&)(t::Isa,  e::Egal) = e & t
(&)(s::Isa, t::Isa) = (samearg(s,t); typepred(s.arg, tintersect(s.typ,t.typ)))


# ---- Intension --------------------------------------------------------------
       
type Intension
    factors::Dict{Node,Predicate}
end

guardsof(x::Intension) = values(x.factors)

depsof(node::Union(Arg, Never, Always))  = []
depsof(node::Union(TupleRef, Egal, Isa)) = [node.arg]
depsof(node::Guard)                      = [node.pred]

depsof(i::Intension,node::Node)     = depsof(node)
depsof(i::Intension,node::TupleRef) = Node[node.arg,Guard(i.factors[node.arg])]


const naught   = Intension((Node=>Predicate)[argnode => never])
const anything = Intension((Node=>Predicate)[])

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

function (&)(p::Pattern, q::Pattern)
    bindings = merge(p.bindings, q.bindings)
#    @assert length(bindings) == length(p.bindings)+length(q.bindings)
    Pattern(p.intent & q.intent, bindings)
end

function show(io::IO, p::Pattern)
    if p.intent === naught; print(io, "::None"); return; end
    
    users = Dict{Node,Set}()
    for (name,arg) in p.bindings; adduser(users, name, arg); end
    for g in guardsof(p.intent);  adduser(users, g);         end

    showpat(io, users, argnode)
end
    
adduser(users::Dict, u::Node) = for d in depsof(u); adduser(users, u, d); end
function adduser(users::Dict, user, dep::Node)
    if !has(users, dep); adduser(users, dep); users[dep] = Set() end
    add(users[dep], user)
end

const typeorder = [Symbol=>1, TupleRef=>2, Egal=>3, Isa=>3]
cmp(x,y) = typeorder[typeof(x)] < typeorder[typeof(y)]
cmp(x::Symbol,   y::Symbol)   = string(x) < string(y)
cmp(x::TupleRef, y::TupleRef) = x.index   < y.index

function showpat(io::IO, users::Dict, node::Node)
    if !has(users, node); print("::Any"); return end

    # printing order: Symbol, TupleRef, Egal, Isa
    us = sort(cmp, {users[node]...})
    k, n = 1, length(us)
    while k <= n
        u = us[k]
        if k > 1 && !isa(u, Isa); print(io, '~'); end
        if isa(u, Symbol); print(io, u)
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
