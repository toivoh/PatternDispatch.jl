module PatternGraphs
export Graph, nodesof, hasnode, keyof
export addnode!, equate!, nevermatches

export argof, tgkey

import ..Common: emit!, calc!, branch!, reemit!
using ..Ops
using ..Graphs
using ..Nodes
import Base: <=, >=, <, >, ==, &


calc!(g::Graph, op::Calc, args::Node...) = addnode!(g, op, args...)

emit!(g::Graph, h::Head, args::Node...) = (addnode!(g, h, args...); nothing)
emit!(g::Graph, ::EgalGuard, n1::Node, n2::Node) = equate!(g, n1, n2)

branch!(g::Graph) = (g2 = Graph(); reemit!(g2, g); g2)


argof(node::Union(Node{TypeGuard},Node{TupleRef})) = argsof(node)[1]
tgkey(node::Node) = keyof(TypeGuard(Any), node)


nevermatches(g::Graph) = hasnode(g, Never())

function addnode!(g::Graph, head::Head, args::Node...)
    if nevermatches(g); return g[keyof(Never())]; end

    node = Graphs.addnode!(g, head, [primary_rep(arg) for arg in args]...)
    Graphs.visit!(g); live_rep(node)
end

function equate!(g::Graph, node1::Node, node2::Node)
    if nevermatches(g); return nothing; end

    Graphs.equate!(g, primary_rep(node1), primary_rep(node2))
    Graphs.visit!(g)
end


# want to keep as much info in the graph as we can, if someone wonders why it matches nothing
never!(g::Graph) = (Graphs.addnode!(g, Never()); nothing)


function Graphs.visit!(g::Graph, node::Node{TypeGuard})
    if Tof(node) <: None; never!(g); end
end

function Graphs.visit!(g::Graph, node::Node{Source})
    if !isprimary(node); never!(g);
    else
        Graphs.addnode!(g, TypeGuard(typeof(valueof(node))), node)
    end
end

function Graphs.visit!(g::Graph, node::Node{TupleRef})
    arg = argof(node)
    if isa(arg, Node{Source})
        t, k = valueof(arg), index_of(node)
        if isa(t, Tuple) && k <= length(t)
            Graphs.replace!(g, node,
                            primary_rep(Graphs.addnode!(g, Source(t[k]))))
        else
            # Do nothing. There should be a typeguard on arg that calls never!
            # Todo: check that it is there?
        end
    end
end


# Lookup the node in g corresponding to the head and args of oldnode,
# using map as a cache. Return nothing if there is no corresponding node in g
function lookup(g::Graph, map::Dict{Node,Union(Node,Nothing)}, oldnode::Node)
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

function <=(p::Graph, q::Graph)
    if     nevermatches(p); return true
    elseif nevermatches(q); return false
    end

    map = (Node=>Union(Node,Nothing))[]
    for qnode in nodesof(q)
        pnode = lookup(p, map, qnode)
        if !isprimary(qnode) && ((pnode === nothing) ||
          !(lookup(p, map, primary_rep(qnode)) === pnode))
            return false
        end
        if isa(qnode, Node{TypeGuard}) &&
          !isa(argof(qnode), Node{Source}) && (Tof(qnode) != Any) &&
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
    Reemit(dest, g::Graph) = new(dest, g, (Node=>Any)[])
end

function reemit!(dest, g::Graph)
    em = Reemit(dest, g)
    for node in values(g.nodes); reemit_node!(em, node); end
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
