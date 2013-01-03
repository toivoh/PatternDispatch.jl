
module Encode
using Meta, Patterns, Dispatch
import Patterns.resultof, Nodes.encode
export ResultsDict, Sequence, sequence!, code_predicate, encoded
export preguard!, provide!
export code_dispatch, seq_dispatch!


# ---- Result: Node type for instantiated results -----------------------------

type Result{T} <: Node{T}
    node::Node{T}
    name::Union(Symbol,Nothing)
    nrefs::Int
    ex
    
    Result(node::Node{T}, name) = new(node, name, 1, nothing)
end
Result{T}(node::Node{T}, name) = Result{T}(node, name)
Result(node::Node)             = Result(node, nothing)

resultof(node::Result) = (@assert node.ex != nothing; node.ex)


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

# ---- sequence decision tree -------------------------------------------------

seq_dispatch!(results::ResultsDict, d::DNode) = nothing
function seq_dispatch!(results::ResultsDict, m::MethodCall)
    s = Sequence(domainof(m.m), results, make_namer([m.m]))
    for node in values(m.m.sig.bindings);  sequence!(s, node)  end
    m.bind_seq = s.seq
    m.bindings = Node[results[node] for node in m.m.bindings]
end
function seq_dispatch!(results::ResultsDict, d::Decision)
    results_fail = copy(results)
    s = Sequence(d.domain, results, make_namer(d.methods))
    for p in predsof(d.domain);  sequence!(s, Guard(p))  end

    k=findfirst(node->isa(node,Guard), s.seq)
    d.pre = s.seq[1:(k-1)]
    d.seq = s.seq[k:end]

    seq_dispatch!(results, d.pass)
    seq_dispatch!(results_fail, d.fail)
end


# ---- decision tree -> dispatch code -----------------------------------------

blockwrap(ex)       = ex
blockwrap(exprs...) = expr(:block, exprs...)

function code_dispatch(::NoMethodNode)
    :( error("No matching pattern method found") )
end
function code_dispatch(m::MethodCall)
    prebind = encoded(m.bind_seq)
    args = {resultof(node) for node in m.bindings}
    blockwrap(prebind...,
         expr(:call, quot(m.m.body), args...))
end
function code_dispatch(d::Decision)
    pre = encoded(d.pre)
    pred = code_predicate(d.seq)
    pass = code_dispatch(d.pass)
    fail = code_dispatch(d.fail)
    code = expr(:if, pred, pass, fail)
    blockwrap(pre..., code)
end

# ---- generate code from (instantiated) node sequence ------------------------

function code_predicate(seq::Vector{Node})
    code = {}
    pred = nothing
    for node in seq
        if isa(node, Guard)
            factor = isempty(code) ? node.pred.ex : expr(:block, code..., node.pred.ex)
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
