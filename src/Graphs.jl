module Graphs
export Graph, nodesof, hasnode
export keyof

import ..Common.keyof
using ..Common.meet
using ..Nodes

# doesn't check that the args are live
keyof(head, args::Node...) = tuple(keyof(head), args...)
keyof(node::Node) = keyof(headof(node), argsof(node)...)


#  Graph Invariants: (when manipulating graphs with the exported functions)
# ===================
#
# * All invariants of Nodes.jl
#
# For a graph g
# * No dead nodes are in g.nodes
#
# Additionally, upon each (recursive) call to setarg!:
# * Each live node in g has a unique key, under which it is stored in g.nodes.
#   (the key may be based on dead argument nodes)
#
# Additonally, outside of setarg!:
# * No live nodes in g have dead arguments


type Graph
    nodes::Dict{Any,Node}
    # Nodes that change head, args, depth, or primary rep, are added here,
    # including new nodes
    visit::Set{Node}

    Graph() = new((Any=>Node)[], Set{Node}())
end

Base.haskey(  g::Graph, key) = haskey(g.nodes, key)
Base.getindex(g::Graph, key) = g.nodes[key]

hasnode(g::Graph, head, args::Node...) = haskey(g, keyof(head, args...))

nodesof(g::Graph) = values(g.nodes)

# Add a new live node (head, args) to the graph or return the existing one
function addnode!(g::Graph, head, args::Node...)
    key = keyof(head, args...)

    if haskey(g.nodes, key)
        node = g.nodes[key]
        if (Nodes.sethead!(node, meet(headof(node), head)))
            push!(g.visit, node)
        end
    else
        node = g.nodes[key] = Node(head, args)
        push!(g.visit, node)
    end
    node
end

function equate!(g::Graph, node1::Node, node2::Node)
    checkprimary(node1); checkprimary(node2);
    if node1 === node2; return; end

    if depthof(node1) >= depthof(node2); from, to = node1, node2
    else                                 from, to = node2, node1
    end

    Nodes.redirect!(from, to)
    substitute_uses!(g, from, to)
    push!(g.visit, from); nothing
end

# Set node.args[k] = arg, update refs, handle key collisions
# node must be live in g, and might become dead
# Returns new live representative node
function setarg!(g::Graph, node::Node, arg::Node, k::Int)
    if argsof(node)[k] === arg; return; end

    key0 = keyof(node)
    Nodes.setarg!(node, arg, k)
    key1 = keyof(node)

    # Remove old key
    @assert pop!(g.nodes, key0) === node # ==> not all live nodes are in g.nodes
    
    if haskey(g.nodes, key1)
        # Merge node into preexisting one, then with preexisting
        to = g.nodes[key1]

        to = live_rep(to) # merge heads and depths on equivalent nodes only
        if (Nodes.sethead!(to, meet(headof(to), headof(node))) ||
          Nodes.setdepth!(to, min(depthof(to), depthof(node))))
            push!(g.visit, to) # push if the node changed
        end

        to = primary_rep(to)
        Nodes.replace!(node, to) # ==> all live nodes in are in g.nodes again
        substitute_uses!(g, node, to)
        equate!(g, primary_rep(node), primary_rep(to))
    else
        # Store at new key
        g.nodes[key1] = node # ==> all live nodes in are in g.nodes again
        push!(g.visit, node)
    end
    nothing
end

visit!(g::Graph, node::Node) = nothing
function visit!(g::Graph)
    while !isempty(g.visit)
        node = pop!(g.visit)
        # If a node has been replaced, the replacement will be in the visit
        # set if it represents something new.
        if islive(node); visit!(g, node); end
    end
end

# Remove from and replace with to
# from must be live
# consider: how does this relate to the invariants?
function replace!(g::Graph, from::Node, to::Node)
    pop!(g.nodes, keyof(from))
    Nodes.replace!(from, to)
    substitute_uses!(g, from, to)
end

# Move all references on from to to
function substitute_uses!(g::Graph, from::Node, to::Node)
    @assert !(from === to)
    refs = refsof(from)
    while !isempty(refs)
        to = primary_rep(to)
        k, ref = first(refs)
        setarg!(g, ref, to, k) # mutates refs
    end
end


end # module
