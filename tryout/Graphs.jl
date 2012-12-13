
module Graphs
import Base.add

abstract Value

type Node
    value::Value
    refs::Set{Node}
    replacement::Union{Node,Nothing}

    Node(value) = new(value, Set{Node}(), nothing)
end

type Graph
    nodes::Dict{Value, Node}
    
    Graph() = new(Dict{Value,Node}())
end

add(g::Graph, v::Value) = (has(g.nodes, v) ? g.nodes[v] : g.nodes[v] = Node(v))

function subs!(g::Graph, from::Value, to::Value) 
    has(g.nodes, from) ? subs!(g, g.nodes[from], to) : nothing
end

function subs!(g::Graph, from::Node, to_value::Value)   
    if has(g.nodes, to_value)
        subs!(g, from, g.nodes[to_value])
    else
        from.value = to_value
        g.nodes[to_value] = from
        return
    end
end

function subs!(g::Graph, from::Node, to::Node)   
    from.replacement = to
    g.nodes[from.value] = to
    # replace from with to in all references to from
    for refnode in from.refs
        subs!(g, refnode, subs(refnode.value, from, to))
    end
    add_each(to.refs, from.refs)
end


end # module
