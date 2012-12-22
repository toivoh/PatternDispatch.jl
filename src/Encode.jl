
module Encode
using Patterns, Toivo
export ResultsDict, Sequence, sequence!, code_predicate, encoded


# ---- sequence!: Create evaluation order, instantiate nodes into Result's ----

typealias ResultsDict Dict{Node,Node}
type Sequence
    intent::Intension
    results::ResultsDict
    seq::Vector{Node}

    Sequence(i::Intension, r::ResultsDict) = new(i, r, Node[])
end
Sequence(intent::Intension) = Sequence(intent,   ResultsDict())
Sequence(s::Sequence)       = Sequence(s.intent, copy(s.results))

wrap(node::Guard) = node
wrap(node::Node)  = Result(node)

function sequence!(s::Sequence, node::Node)
    if has(s.results, node)
        newnode = s.results[node]
        if isa(newnode, Result); newnode.nrefs += 1; end
        return
    end

    for dep in depsof(s.intent, node);  sequence!(s, dep)  end
    newnode = s.results[node] = wrap(subs(s.results, node))
    push(s.seq, newnode)
end


# ---- code_match etc: generate code from (instantiated) node sequence --------

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
        var = gensym("t")
        node.ex = var
        push(code, :( $var = $ex ))
    end
end

end # module
