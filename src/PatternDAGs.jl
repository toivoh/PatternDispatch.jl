module PatternDAGs

export PatternDAG, hasnode, nevermatches
export TGof

using ..Common.Head
using ..Ops: Calc, EgalGuard, TypeGuard, Tof, Never, Source, valueof
import ..Common: emit!, calc!
using ..DAGs


tgkey(node::Node) = keyof(TypeGuard(Any), node)
TGof(g, node::Node) = (key = tgkey(primary_rep(node)); haskey(g, key) ? Tof(headof(g[key])) : Any)


immutable PatternDAG
    g::DAG
    PatternDAG() = new(DAG())
end

Base.haskey(  g::PatternDAG, key) = haskey(g.g, key)
Base.getindex(g::PatternDAG, key) = g.g[key]

hasnode(g::PatternDAG, head, args::Node...) = haskey(g, keyof(head, args...))

function emit!(g::PatternDAG, head::Head, args::Node...)
    if head === TypeGuard(None); never!(g); end # todo: avoid having to place it here?
    emit!(g.g,head,args...)
    simplify!(g)
    nothing
end
function calc!(g::PatternDAG, head::Head, args::Node...)
    node = calc!(g.g, head, args...)
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

nevermatches(g::PatternDAG) = hasnode(g, Never())

never!(g::PatternDAG) = (emit!(g, Never()); nothing)

visit!(g::PatternDAG, node::Node) = nothing
visit!(g::PatternDAG, node::Node{TypeGuard}) = (if Tof(headof(node)) == None; never!(g); end)
# NB: assumes all nodes that become secondary end up in updated
visit!(g::PatternDAG, node::Node{Source}) = (if !(primary_rep(node) === node); never!(g); end)

function simplify!(g::PatternDAG)
    while !isempty(g.g.updated)
        node = pop!(g.g.updated)
        if !iskind(active_node, node); continue; end
        visit!(g, node)
    end    
end


end # module
