
module Nodes
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<, Base.show
import Patterns.depsof, Patterns.subs, Patterns.intension
using Meta, Immutable, Patterns
export argsym, argnode, refnode, lengthnode, egalpred, typepred
export julia_signature_of


# ---- nodes ------------------------------------------------------------------

type Arg <: Node{Any}; end
const argnode = Arg()
const argsym  = gensym("arg")

@immutable type Ref    <: Node{Any};  arg::Node; index::Int;  end
@immutable type Length <: Node{Any};  arg::Node;              end
@immutable type Egal   <: Predicate;  arg::Node; value;       end
@immutable type Isa    <: Predicate;  arg::Node; typ;         end

refnode(   arg::Node, index::Int) = Ref(arg, index)
lengthnode(arg::Node)             = Length(arg)
egalpred(  arg::Node, value)      = Egal(arg, value)

typepred(arg::Node, ::Type{Any})  = always
typepred(arg::Node, ::Type{None}) = never
typepred(arg::Node, typ)          = Isa(arg, typ)

subs(d::Dict, node::Union(Arg, Atom)) = node
subs(d::Dict, node::Ref)    = Ref(   d[node.arg], node.index)
subs(d::Dict, node::Length) = Length(d[node.arg])
subs(d::Dict, node::Egal)   = Egal(  d[node.arg], node.value)
subs(d::Dict, node::Isa)    = Isa(   d[node.arg], node.typ)

encode(v::Arg)    = argsym
encode(v::Ref)    = :( $(resultof(v.arg))[$(v.index)] )
encode(v::Length) = :(length($(resultof(v.arg))))
encode(g::Egal)   = :(is( $(resultof(g.arg)), $(quot(g.value))))
encode(g::Isa)    = :(isa($(resultof(g.arg)), $(quot(g.typ  ))))


(&)(node1::Atom{Bool}, node2::Atom{Bool}) = Atom(node1.value & node2.value)
(&)(node1::Predicate,  node2::Atom{Bool}) = node2.value ? node1 : never
(&)(node1::Atom{Bool}, node2::Predicate) = node2 & node1

# to work around that type equivalence is weaker than isequal
# works together with >=(::Intension, ::Intension)
mytintersect(S,T) = (T <: S) ? T : tintersect(S,T)

samearg(n::Node, m::Node) = @assert n.arg===m.arg
(&)(e::Egal, f::Egal) = (samearg(e, f); e.value === f.value ? e : never)
(&)(e::Egal, t::Isa)  = (samearg(e, t); isa(e.value, t.typ) ? e : never)
(&)(t::Isa,  e::Egal) = e & t
(&)(s::Isa, t::Isa) = (samearg(s,t); typepred(s.arg,mytintersect(s.typ,t.typ)))

depsof(node::Union(Arg, Atom))     = []
depsof(node::Union(Ref, Length, Egal, Isa)) = [node.arg]

function depsof(i::Intension, n::Ref)
    Node[n.arg, Guard(i.factors[n.arg]), Guard(i.factors[Length(n.arg)])]
end
depsof(i::Intension, node::Length) = Node[node.arg, Guard(i.factors[node.arg])]

function intension(Ts::Tuple)
    intension(typepred(argnode, Tuple),
              egalpred(lengthnode(argnode), length(Ts)),
              {typepred(refnode(argnode, k),T) for (k,T) in enumerate(Ts)}...)
end

get_type(g::Isa)  = g.typ
get_type(g::Egal) = typeof(g.value)
function get_type(intent::Intension, node::Node)
    has(intent.factors, node) ? get_type(intent.factors[node]) : Any
end
function julia_signature_of(intent::Intension)
    if !has(intent.factors, argnode);  return Tuple;  end
    garg::Isa = intent.factors[argnode]
    @assert garg.typ <: Tuple
    glen::Egal = intent.factors[Length(argnode)]
    nargs = glen.value
    tuple({get_type(intent, refnode(argnode, k)) for k=1:nargs}...)
end
julia_signature_of(p::Pattern) = julia_signature_of(p.intent)


function show(io::IO, p::Pattern)
    if p.intent === naught; print(io, "::None"); return; end
    
    users = Dict{Node,Set}()
    for (name,arg) in p.bindings; adduser(users, name, arg); end
    for g in predsof(p.intent);  adduser(users, g);         end

    showpat(io, users, argnode)
end
    
adduser(users::Dict, u::Node) = for d in depsof(u); adduser(users, u, d); end
function adduser(users::Dict, user, dep::Node)
    if !has(users, dep); adduser(users, dep); users[dep] = Set() end
    add(users[dep], user)
end

const typeorder = [Symbol=>1, Length=>2, Egal=>3, Isa=>3, Ref=>4]
cmp(x,y) = typeorder[typeof(x)] < typeorder[typeof(y)]
cmp(x::Symbol, y::Symbol) = string(x) < string(y)
cmp(x::Ref,    y::Ref)    = x.index   < y.index

function showpat(io::IO, users::Dict, node::Node)
    if !has(users, node); print("::Any"); return end

    # printing order: Symbol, Ref, Egal, Isa
    us = sort(cmp, {users[node]...})
    k, n = 1, length(us)
    printed = false
    typ = Any
    while k <= n
        u = us[k]
#        if k > 1 && !isa(u, Isa); print(io, '~'); end
        if printed && !(isa(u, Isa) || isa(u, Length)); print(io, '~'); end
        if isa(u, Symbol); print(io, u); printed = true
        elseif isa(u, Egal); print(io, u.value); printed = true
        elseif isa(u, Isa)
            typ = u.typ
            if k+1 <= n && isa(us[k+1], Ref)
                if (u.typ == Tuple) || (u.typ == Vector)
                    k += 1
                    continue
                end
            end
            print(io, "::", u.typ); printed = true            
        elseif isa(u, Length) # todo: do something
        elseif isa(u, Ref)
#            print(io, '(')
            print(io, typ <: Vector ? '[' : '(')
            i = 0
            while k <= n && isa(us[k], Ref)
                if i==0; i=1; end
                u = us[k]
                @assert i <= u.index
                while i < u.index; print(io, ", "); i += 1; end
                i = u.index
                showpat(io, users, u)
                k += 1
            end
            if i == 1; print(io, ','); end
            print(io, typ <: Vector ? ']' : ')')
#            print(io, ')')
#            if k == n && isa(us[k], Isa) && us[k].typ == Tuple; return; end
            printed = true
        else
            error("unknown node type")
        end
        k += 1
    end
end

end # module
