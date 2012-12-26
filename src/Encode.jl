
module Encode
using Meta, Patterns
import Nodes.encode
export ResultsDict, Sequence, sequence!, code_predicate, encoded
export preguard!, provide!


# ---- sequence!: Create evaluation order, instantiate nodes into Result's ----

typealias ResultsDict Dict{Node,Node}
type Sequence
    intent::Intension
    results::ResultsDict
    namer::Function
    seq::Vector{Node}

    Sequence(i::Intension, r::ResultsDict, namer) = new(i, r, namer, Node[])
end

wrap(s::Sequence, node::Guard, orig_node::Node) = node
function wrap(s::Sequence, node::Node, orig_node::Node)
    Result(node, s.namer === nothing ? nothing : s.namer(orig_node))
end

function sequence!(s::Sequence, node::Node)
    if has(s.results, node)
        newnode = s.results[node]
        if isa(newnode, Result); newnode.nrefs += 1; end
        return
    end

    for dep in depsof(s.intent, node);  sequence!(s, dep)  end
    newnode = s.results[node] = wrap(s, subs(s.results, node), node)
    push(s.seq, newnode)
end

preguard!(results::ResultsDict, g::Guard) = (results[g] = Guard(always))
function provide!(results::ResultsDict, node::Node, ex)
    res = Result(node)
    res.ex = ex
    results[node] = res
end


# ---- generate code from (instantiated) node sequence ------------------------

function code_predicate(seq::Vector{Node})
    code = {}
    pred = nothing
    for node in seq
        if isa(node, Guard)
            factor = isempty(code) ? node.pred.ex :  quote; $(code...); $(node.pred.ex) end
            pred = pred === nothing ? factor : (:($pred && $factor))
            code = {}
        else
            encode!(code, node)
        end
    end
    pred
end

function encoded(seq::Vector{Node})
    code = {}
    for node in seq;  encode!(code, node);  end
    code
end

encode!(code::Vector, ::Guard) = error("Undefined!")
function encode!(code::Vector, node::Result)
    if node.ex != nothing;  return  end
    ex = encode(node.node)

    if isa(ex, Symbol) || node.nrefs == 1
        node.ex = ex
    else
        var = node.name === nothing ? gensym("t") : node.name
        node.ex = var
        push(code, :( $var = $ex ))
    end
end

end # module
