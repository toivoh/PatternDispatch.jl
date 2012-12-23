
module PartialOrder
export insert!, subDAGof

type Node{T}
    value::T
    gt::Set{Node{T}}
    
    Node(value) = new(value, Set{Node{T}}())
end
Node{T}(value::T) = Node{T}(value)

subDAGof{T}(node::Node{T}) = (sub = Set{Node{T}}(); addsubDAG!(sub, node); sub)
function addsubDAG!{T}(seen::Set{Node{T}}, node::Node{T})
    if has(seen, node); return; end
    add(seen, node)
    for below in node.gt; addsubDAG!(seen, below); end       
end

insert!{T}(at::Node{T}, node::Node{T}) = insert!(Set{Node{T}}(), at, node)
function insert!{T}(seen::Set{Node{T}}, at::Node{T}, node::Node{T})
    if has(seen, at); return; end
    add(seen, at)
    if node.value >= at.value
        if at.value >= node.value 
            at.value = node.value  # at == node
            return true
        end
        # node > at
        add(node.gt, at)
        at_above_node = false
    else
        at_above_node = any([insert!(seen, below, node) for below in at.gt])
    end
    if !at_above_node
        if at.value >= node.value
            del_each(at.gt, at.gt & node.gt)
            add(at.gt, node)
            at_above_node = true
        end
    end
    at_above_node
end

end # module