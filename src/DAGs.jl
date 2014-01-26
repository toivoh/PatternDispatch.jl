module DAGs

export DAG, primary_rep
export TGof

using ..Common.Head
import ..Common
using ..Ops: Calc, EgalGuard, TypeGuard, Tof, Never, Source, valueof
import ..Common: emit!, calc!, meet


# Kinds (node.kind) for the replacement node (node.rep)
const primary_node = 0  # No replacement
const active_node  = 1  # Egal guard to rep
const live_node    = 2  # Replaced by rep
const merged_node  = 3  # Redirects to another node with same key; node is not in the DAG

type Node{H<:Head}
    head::H
    args::Vector{Node}

    depth::Int

    kind::Int
    rep_or_uses::Union(Set{(Int,Node)}, Node) # Set if kind == primary_node, Node otherwise

    function Node(head::H, args::Node...)
        args = Node[args...]
        depth = length(args)==0 ? 0 : maximum([depthof(arg) for arg in args])+1        
        node = new(head, args, depth, primary_node, Set{(Int,Node)}())
        for (k,arg) in enumerate(args); adduse!(arg, (k,node)); end
        node
    end
end
Node{H}(head::H, args...) = Node{H}(head, args...)

typealias Use (Int,Node)

function Base.show(io::IO, node::Node)
    print(io, "Node(", headof(node), ", ")
    show(io, argsof(node))
    print(io, ')')
end

headof(node::Node)  = (checkkind(live_node, node); node.head)
argsof(node::Node)  = (checkkind(live_node, node); node.args)
depthof(node::Node) = node.depth
usesof(node::Node)  = node.rep_or_uses::Set{Use}

iskind(   kind::Int, node::Node) = (node.kind <= kind)
checkkind(kind::Int, node::Node) = (@assert iskind(kind, node))

primary_rep(node::Node) = getrep(primary_node, node)
#active_rep(node::Node)  = getrep(active_node, node)

headkey(head::Head) = Common.keyof(head)
headkey(head::Calc) = head

keyof(node::Node) = keyof(node.head, node.args...)
keyof(head::Head, args::Node...) = tuple(headkey(head), args...)


adduse!(node::Node, u::Use) = (push!(  usesof(node), u); nothing)
deluse!(node::Node, u::Use) = (delete!(usesof(node), u); nothing)

# Set rep and kind, take uses. kind is the kind that node becomes; rep must have narrower kind
function setrep!(kind::Int, node::Node, rep::Node)
    @assert primary_node < kind <= merged_node
    checkkind(kind, node); checkkind(kind-1, rep)
    @assert depthof(rep) <= depthof(node)
    node.kind = kind
    node.rep_or_uses  = rep # returns rep
end
    
function getrep(kind::Int, node::Node)
    if kind < live_node; node = getrep(kind+1, node); end
    iskind(kind, node) ? node : setrep!(kind+1, node, getrep(kind, node.rep_or_uses::Node))
end

# Definitions:
# * A node is in the DAG if it is in g.nodes
# * A primary node has primary_rep(node) === node <==> it has not been substitued
# * An edge from a node to one of its arguments is in the graph iff the user is
# * An edge in the graph is owned by the argument if it is primary; otherwise by substitute!
#
# Invariants:
# * The nodes and edges form a DAG
# * A node is in the DAG iff it has kind <= live_node
# * A node always has greater depth than its arguments
# * An edge in the graph has exactly one owner, which may be one invocation of substitute
#   - The edge's destination may only be changed by the owner
#   ==> if no instances of substitute! exist, the edge is owned by the argument, which is primary
# * A node in the DAG is stored under its key in g.nodes (and no other keys)

type DAG
    nodes::ObjectIdDict
    updated::Set{Node}

    DAG() = new(ObjectIdDict(), Set{Node}())
end

Base.haskey(  g::DAG, key) = haskey(g.nodes, key)
Base.getindex(g::DAG, key) = g.nodes[key]

merge_node!(g::DAG, key, head::Calc) = g.nodes[key]
function merge_node!(g::DAG, key, head::Head)
    node = g.nodes[key]
    h0, k0 = node.head, headkey(node.head)
    node.head = meet(node.head, head)
    @assert headkey(node.head) === k0
    if !(node.head === h0); push!(g.updated, node); end
    node
end

emit!(g::DAG, head::Head, args::Node...) = (calc!(g, head, args...); nothing)
function calc!(g::DAG, head::Head, args::Node...)
    args = Node[primary_rep(arg) for arg in args]
    key = keyof(head, args...)
    haskey(g.nodes, key) ? merge_node!(g, key, head) : (g.nodes[key] = Node(head, args...))
end

# todo: would be nice not to have to define these two:
emit!(g::DAG, ::EgalGuard, args::Node...) = error("Invalid")
calc!(g::DAG, ::EgalGuard, args::Node...) = error("Invalid")

function emit!(g::DAG, ::EgalGuard, n1::Node, n2::Node)
    n1, n2 = primary_rep(n1), primary_rep(n2)
    if n1 === n2; return; end
    from, to = depthof(n1) >= depthof(n2) ? (n1, n2) : (n2, n1)
    substitute!(g, active_node, from, to)
    nothing
end

# Substitute uses of node from with primary rep of node to
# Assumes that from is primary
function substitute!(g::DAG, kind::Int, from::Node, to::Node)
    to = primary_rep(to)
    @assert !(from === to)
    
    # Steal the edges from the arguments that use from, and redirect from to to
    uses = usesof(from)
    setrep!(kind, from, to)

    # substitute uses of from for to
    for (k,user) in uses
        if !iskind(live_node, user); continue; end # The edge was already taken out of the DAG
        to = primary_rep(to)

        removed = pop!(g.nodes, keyof(user)); @assert removed === user # remove at old key
        user.args[k] = to      # update argument
        adduse!(to, (k,user)) # Give edge to to; substitute! will not use it anymore
        # Try to store user at the new key
        key = keyof(user)
        if haskey(g.nodes, key)
            # Couldn't store user at the new key, so remove it from the DAG instead
            user0 = g.nodes[key]
            user0.depth = min(user0.depth, user.depth) # update depth of collided node
            merge_node!(g, key, headof(user))
            # Delete edges from user, since we take it out of the DAG
            for (l,arg) in enumerate(argsof(user)); deluse!(arg, (l,user)); end
            # Substitute user if it is primary; otherwise merge the equivalence classes
            rep = primary_rep(user)
            if rep === user
                substitute!(g, merged_node, user, user0)
            else
                setrep!(merged_node, user, user0)
                emit!(g, EgalGuard(), rep, user0)
            end
        else
            g.nodes[key] = user # store at new key
            push!(g.updated, user)
        end
    end
end


tgkey(node::Node) = keyof(TypeGuard(Any), node)
TGof(g, node::Node) = (key = tgkey(primary_rep(node)); haskey(g, key) ? Tof(headof(g[key])) : Any)


immutable PatternDAG
    g::DAG
    PatternDAG() = new(DAG())
end

Base.haskey(  g::PatternDAG, key) = haskey(g.g, key)
Base.getindex(g::PatternDAG, key) = g.g[key]

emit!(g::PatternDAG, head::Head, args::Node...) = (emit!(g.g, head, args!); simplify!(g); nothing)
function calc!(g::PatternDAG, head::Head, args::Node...)
    node = calc!(g.g, head, args!)
    simplify!(g)
    primary_rep(node) # consider: do we want to take the primary_rep here? active_rep?
end

calc!(g::PatternDAG, head::Source, args::Node...) = error("Source nodes take no args")
function calc!(g::PatternDAG, head::Source)
    node = calc!(g.g, head)
    emit!(g.g, TypeGuard(typeof(valueof(head))), node)
    # NB: below duplicated from common calc! How to avoid?
    simplify!(g)
    primary_rep(node) # consider: do we want to take the primary_rep here? active_rep?
end

never!(g::PatternDAG) = (emit!(g, Never()); nothing)

visit!(g::PatternDAG, node::Node) = nothing
visit!(g::PatternDAG, node::Node{TypeGuard}) = (if Tof(headof(node)) == None; never!(g); end)
# NB: assumes all nodes that become secondary end up in updated
visit!(g::PatternDAG, node::Node{Source}) = (if !primary_rep(node) === node; never!(g); end)

function simplify!(g::PatternDAG)
    while !isempty(g.g.updated)
        node = pop!(g.g.updated)
        if !iskind(active_node, node); continue; end
        visit!(g, node)
    end    
end


end # module
