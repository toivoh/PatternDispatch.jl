
module PartialOrder
export Node, insert!, subDAGof, ordered_subDAGof, copyDAG, raw_filter!

type Node{T}
    value::T
    gt::Set{Node{T}}
    
    Node(value) = new(value, Set{Node{T}}())
    Node(value, gt) = new(value, gt)
end
Node{T}(value::T) = Node{T}(value)

copyDAG{T}(top::Node{T}) = copyDAG((Node{T}=>Node{T})[], top)
function copyDAG{T}(subs::Dict{Node{T},Node{T}}, node::Node{T})
    if haskey(subs, node); return subs[node] end
    
    gt = Set{Node{T}}([copyDAG(subs, child) for child in node.gt])
    subs[node] = Node{T}(node.value, gt)
end

raw_filter!{T}(n::Node{T}, keep::Set{T}) = raw_filter!(Set{Node{T}}(), n, keep)
function raw_filter!{T}(seen::Set{Node{T}}, node::Node{T}, keep::Set{T})
    if node in seen; return end
    push!(seen, node)
    node.gt = Set{Node{T}}(filter(node->(node.value in keep), node.gt))
    for child in node.gt;  raw_filter!(child, keep)  end
end

subDAGof{T}(node::Node{T}) = (sub = Set{Node{T}}(); addsubDAG!(sub, node); sub)
function addsubDAG!{T}(seen::Set{Node{T}}, node::Node{T})
    if node in seen; return; end
    push!(seen, node)
    for below in node.gt; addsubDAG!(seen, below); end       
end

function ordered_subDAGof{T}(node::Node{T}) 
    seen, order = Set{Node{T}}(), Node{T}[]
    addsubDAG!(seen, order, node)
    order
end
function addsubDAG!{T}(seen::Set{Node{T}},order::Vector{Node{T}},node::Node{T})
    if node in seen; return; end
    push!(seen, node); push!(order, node)
    for below in node.gt; addsubDAG!(seen, order, below); end       
end


insert!{T}(at::Node{T}, node::Node{T}) = insert!((Node{T}=>Bool)[], at, node)
function insert!{T}(seen::Dict{Node{T},Bool}, at::Node{T}, node::Node{T})
    if haskey(seen, at); return seen[at] end
    if node.value >= at.value
        if at.value >= node.value 
            at.value = node.value  # at == node
            return seen[at] = true
        end
        # node > at
        push!(node.gt, at)
        at_above_node = false
    else
        at_above_node = any([insert!(seen, below, node) for below in at.gt])
    end
    if !at_above_node
        if at.value >= node.value
            setdiff!(at.gt, intersect(at.gt, node.gt))
            push!(at.gt, node)
            at_above_node = true
        end
    end
    seen[at] = at_above_node
end

end # module