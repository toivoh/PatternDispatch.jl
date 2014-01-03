module Nodes
export Node, headof, argsof, depthof, refsof
export primary_rep, live_rep, isprimary, islive, checkprimary, checklive

using Common.Head
import Common.headof

# Kinds (node.kind) for the replacement node (node.rep)
const primary_node = 0 # No replacement
const live_node    = 1 # Egal-guard to replacement
const merged_node  = 2 # Trying to create this node gives replacement


#  Node Invariants: (when manipulating Node:s with the functions in Nodes.jl)
# ==================
#
# * A live node has arguments; a dead node has a redirection (get with live_rep)
#
# * Each argument represents an edge from the node to its argument;
#   and is matched by a reference from the argument back to the node
#
# * All references lead to live nodes
#
# * Arguments may be live or dead
#
# Enforced:
# * Each (live) node has greater depth than its arguments (error otherwise)
#
# * Each (dead) node is at least as deep as its replacement

type Node{H<:Head}
    head::H
    args::Vector{Node}

    depth::Int
    refs::Set{(Int,Node)}
    
    kind::Int
    rep::Node

    function Node(head::H, args)
        args = Node[args...]
        depth = length(args)==0 ? 0 : maximum([depthof(arg) for arg in args])+1
        node = new(head, args, depth, Set{(Int,Node)}(), primary_node)
        for (k,arg) in enumerate(args); addref!(arg, (k,node)); end
        node
    end
end

repof(node::Node) = node.rep

iskind(   kind::Int, node::Node) = (node.kind <= kind)
checkkind(kind::Int, node::Node) = (@assert iskind(kind, node))

function set_rep!(kind::Int, node::Node, rep::Node)
    checkkind(kind+1, node); checkkind(kind, rep)
    @assert depthof(rep) <= depthof(node)
    node.kind = kind+1
    node.rep  = rep # returns rep
end
    
# Follow the redirection chain from node to the first node of kind.
# The returned node is never deeper than node.
function get_rep(kind::Int, node::Node)
    if kind < live_node; node = get_rep(kind+1, node); end
    iskind(kind, node) ? node : set_rep!(kind, node, get_rep(kind, repof(node)))
end


isprimary(node::Node) = iskind(primary_node, node)
islive(   node::Node) = iskind(live_node,    node)
checkprimary(node::Node) = checkkind(primary_node, node)
checklive(   node::Node) = checkkind(live_node,    node)
set_primary_rep!(node::Node, rep::Node) = set_rep!(primary_node, node, rep)
set_live_rep!(   node::Node, rep::Node) = set_rep!(primary_node, node, rep)
primary_rep(node::Node) = get_rep(primary_node, node)
live_rep(   node::Node) = get_rep(live_node,    node)

# Accessors. args and refs are not to be mutated
headof(node::Node)  = (checklive(node); node.head)
argsof(node::Node)  = (checklive(node); node.args)
depthof(node::Node) = node.depth # todo: only allow if live?
refsof(node::Node)  = node.refs  # set of (arg_index,node) tuples

# Return true if the head/depth changed
function sethead!{H}(node::Node{H}, head::H)
    checklive(node);
    if head == node.head; false
    else                  node.head = head; true
    end
end
function setdepth!(node::Node, depth::Int)
    checklive(node);
    if depth == node.depth; false
    else                    node.depth = depth; true
    end
end

# Create a live node with given head and args, and deeper than args
Node{H}(head::H, args) = Node{H}(head, args)

# Set node.args[k] = arg, update refs. 
# node must be live, and deeper than arg
function setarg!(node::Node, arg::Node, k::Int)
    checklive(node); checkprimary(arg)
    @assert depthof(node) > depthof(arg)
    args = argsof(node)

    delref!(args[k], (k,node))
    args[k] = arg
    addref!(arg, (k,node))
end

function redirect!(from::Node, to::Node)
    checkprimary(from); checkprimary(to)
    set_primary_rep!(from, to)
end

# Redirect from to to, remove refs to it.
# from must be live, becomes dead. to must not be deeper than from.
function replace!(from::Node, to::Node)
    checklive(from); checkprimary(to)
    for (k, arg) in enumerate(argsof(from)); delref!(arg, (k, from)); end
    set_live_rep!(from, to)
end


# Internals

typealias Ref (Int,Node)

addref!(node::Node, r::Ref) = (checkprimary(node);push!(refsof(node),r);nothing)
delref!(node::Node, r::Ref) = (pop!(refsof(node), r); nothing)

function Base.show(io::IO, node::Node)
    print(io, "Node(", headof(node), ", ")
    show(io, argsof(node))
    print(io, ')')
end

end # module
