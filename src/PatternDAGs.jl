module PatternDAGs

export Graph, nodesof, hasnode, nevermatches
export TGof, tgkey

using ..Common.Head
using ..Ops
import ..Common: emit!, calc!, branch!, reemit!, keyof
using ..DAGs
import Base: <=, >=, <, >, ==, &

argof(node::Union{Node{TypeGuard},Node{TupleRef}}) = argsof(node)[1]
tgkey(node::Node) = keyof(TypeGuard(Any), node)

TGof(g, node::Node) = (key = tgkey(primary_rep(node)); haskey(g, key) ? Tof(headof(g[key])) : Any)


immutable Graph
    g::DAG
    Graph() = new(DAG())
end

nodesof(g::Graph) = values(g.g.nodes) # todo: go through DAG

Base.haskey(  g::Graph, key) = haskey(g.g, key)
Base.getindex(g::Graph, key) = g.g[key]

hasnode(g::Graph, head, args::Node...) = haskey(g, keyof(head, args...))

branch!(g::Graph) = (g2 = Graph(); reemit!(g2, g); g2)

function emit!(g::Graph, head::Head, args::Node...)
    if head === TypeGuard(Union{}); never!(g); end # todo: avoid having to place it here?
    emit!(g.g,head,args...)
    simplify!(g)
    nothing
end
function calc!(g::Graph, head::Head, args::Node...)
    node = calc!(g.g, head, args...)
    # todo: better place for this?
    if head == Call(tuple)
        emit!(g.g, TypeGuard(NTuple{length(args)}), node)
    end
    simplify!(g)
    primary_rep(node) # consider: do we want to take the primary_rep here? active_rep?
end

calc!(g::Graph, head::Source, args::Node...) = error("Source nodes take no args")
function calc!(g::Graph, head::Source)
    node = calc!(g.g, head)
    emit!(g.g, TypeGuard(typeof(valueof(head))), node)
    # NB: below duplicated from common calc! How to avoid?
    simplify!(g)
    primary_rep(node) # consider: do we want to take the primary_rep here? active_rep?
end

nevermatches(g::Graph) = hasnode(g, Never())

never!(g::Graph) = (emit!(g, Never()); nothing)

visit!(g::Graph, node::Node) = nothing
visit!(g::Graph, node::Node{TypeGuard}) = (if Tof(headof(node)) == Union{}; never!(g); end)
# NB: assumes all nodes that become secondary end up in updated
visit!(g::Graph, node::Node{Source}) = (if !(primary_rep(node) === node); never!(g); end)

function simplify!(g::Graph)
    while !isempty(g.g.updated)
        node = pop!(g.g.updated)
        if !iskind(active_node, node); continue; end
        visit!(g, node)
    end
end



# Lookup the node in g corresponding to the head and args of oldnode,
# using map as a cache. Return nothing if there is no corresponding node in g
function lookup(g::Graph, map::Dict{Node,Union{Node,Void}}, oldnode::Node)
    if haskey(map, oldnode); return map[oldnode]; end

    head = headof(oldnode)
    args = [lookup(g, map, arg) for arg in argsof(oldnode)]
    for arg in args
        if arg === nothing
            return map[oldnode] = nothing
        end
    end
    key = keyof(head, args...)
    if !haskey(g, key); return map[oldnode] = nothing; end
    return map[oldnode] = primary_rep(g[key])
end

function isimplied(node::Node{TypeGuard})
    T = Tof(node)
    if T == Any; return true; end
    arg = argof(node)
    if isa(arg, Node{Source}); return true; end
    if headof(arg) === Call(tuple) && NTuple{length(argsof(arg))} <: T; return true; end
    false
end

function <=(p::Graph, q::Graph)
    if     nevermatches(p); return true
    elseif nevermatches(q); return false
    end

    map = Dict{Node,Union{Node,Void}}()
    for qnode in nodesof(q)
        pnode = lookup(p, map, qnode)
        if !isprimary(qnode) && ((pnode === nothing) ||
          !(lookup(p, map, primary_rep(qnode)) === pnode))
            return false
        end
        if isa(qnode, Node{TypeGuard}) &&
          !isimplied(qnode) &&
          ((pnode === nothing) || !(Tof(pnode) <: Tof(qnode)))
            return false
        end
    end
    return true
end

>=(g1::Graph, g2::Graph) = g2 <= g1
>( g1::Graph, g2::Graph) = (g1 >= g2) && !(g2 >= g1)
==(g1::Graph, g2::Graph) = (g1 >= g2) && (g2 >= g1)
<( g1::Graph, g2::Graph) = g2 > g1

(&)(g1::Graph, g2::Graph) = (g = Graph(); reemit!(g, g1); reemit!(g, g2); g)


immutable Reemit
    dest
    g::Graph
    map::Dict{Node, Any} # todo: provide type info about results?
    Reemit(dest, g::Graph) = new(dest, g, Dict{Node,Any}())
end

function reemit!(dest, g::Graph)
    em = Reemit(dest, g)
    for node in nodesof(g); reemit_node!(em, node); end
    em.map
end

function reemit_node!(em::Reemit, node::Node)
    if haskey(em.map, node); return em.map[node]; end

    args = [reemit_node!(em, arg) for arg in argsof(node)]
    result = em.map[node] = reemit_node!(em.dest, headof(node), args)

    if !isprimary(node)
        emit!(em.dest, EgalGuard(), result, reemit_node!(em, primary_rep(node)))
    end

    # Make sure that node's TypeGuard is emitted right after it
    key = tgkey(node)
    if haskey(em.g, key); reemit_node!(em, em.g[key]); end

    result
end

reemit_node!(dest, head::Head, args) = (emit!(dest, head, args...); nothing)
reemit_node!(dest, head::Calc, args) = calc!(dest, head, args...)


end # module
