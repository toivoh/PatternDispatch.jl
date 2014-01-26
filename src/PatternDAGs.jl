module PatternDAGs

export Graph, hasnode, nevermatches
export TGof

using ..Common.Head
using ..Ops: Calc, EgalGuard, TypeGuard, Tof, Never, Source, valueof
import ..Common: emit!, calc!
using ..DAGs


tgkey(node::Node) = keyof(TypeGuard(Any), node)
TGof(g, node::Node) = (key = tgkey(primary_rep(node)); haskey(g, key) ? Tof(headof(g[key])) : Any)


immutable Graph
    g::DAG
    Graph() = new(DAG())
end

Base.haskey(  g::Graph, key) = haskey(g.g, key)
Base.getindex(g::Graph, key) = g.g[key]

hasnode(g::Graph, head, args::Node...) = haskey(g, keyof(head, args...))

function emit!(g::Graph, head::Head, args::Node...)
    if head === TypeGuard(None); never!(g); end # todo: avoid having to place it here?
    emit!(g.g,head,args...)
    simplify!(g)
    nothing
end
function calc!(g::Graph, head::Head, args::Node...)
    node = calc!(g.g, head, args...)
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
visit!(g::Graph, node::Node{TypeGuard}) = (if Tof(headof(node)) == None; never!(g); end)
# NB: assumes all nodes that become secondary end up in updated
visit!(g::Graph, node::Node{Source}) = (if !(primary_rep(node) === node); never!(g); end)

function simplify!(g::Graph)
    while !isempty(g.g.updated)
        node = pop!(g.g.updated)
        if !iskind(active_node, node); continue; end
        visit!(g, node)
    end    
end


end # module
