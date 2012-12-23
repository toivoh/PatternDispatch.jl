
module Nodes
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<, Base.show
import Patterns.depsof, Patterns.subs
using Immutable, Patterns, Toivo
export argsym, argnode, never, always, tupref, egalpred, typepred
export julia_signature_of, julia_intension


# ---- nodes ------------------------------------------------------------------

type Arg    <: Node{Any}; end
const argnode = Arg()
const argsym  = gensym("arg")

@immutable type TupleRef <: Node{Any};  arg::Node; index::Int;  end
@immutable type Egal     <: Predicate;  arg::Node; value;       end
@immutable type Isa      <: Predicate;  arg::Node; typ;         end

tupref(  arg::Node, index::Int) = TupleRef(arg, index)
egalpred(arg::Node, value)      = Egal(arg, value)

typepred(arg::Node, ::Type{Any})  = always
typepred(arg::Node, ::Type{None}) = never
typepred(arg::Node, typ) = Isa(arg, typ)

subs(d::Dict, node::Union(Arg, Never, Always)) = node
subs(d::Dict, node::TupleRef) = TupleRef(d[node.arg], node.index)
subs(d::Dict, node::Egal)     = Egal(    d[node.arg], node.value)
subs(d::Dict, node::Isa)      = Isa(     d[node.arg], node.typ)

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

depsof(node::Union(Arg, Never, Always))  = []
depsof(node::Union(TupleRef, Egal, Isa)) = [node.arg]

depsof(i::Intension,node::TupleRef) = Node[node.arg,Guard(i.factors[node.arg])]


function julia_intension(Ts::Tuple)
    intension(typepred(argnode, NTuple{length(Ts),Any}),
              {typepred(tupref(argnode, k),T) for (k,T) in enumerate(Ts)}...)
end

get_type(g::Isa)  = g.typ
get_type(g::Egal) = typeof(g.value)
function get_type(intent::Intension, node::Node)
    has(intent.factors, node) ? get_type(intent.factors[node]) : Any
end
function julia_signature_of(intent::Intension)
    garg::Isa = intent.factors[argnode]
    @assert garg.typ <: Tuple
    nargs = length(garg.typ)
    tuple({get_type(intent, tupref(argnode, k)) for k=1:nargs}...)
end


julia_signature_of(p::Pattern) = julia_signature_of(p.intent)


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
