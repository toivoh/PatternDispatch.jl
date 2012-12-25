
module DecisionTree
import Base.==
import PartialOrder
import Nodes.julia_signature_of
using PartialOrder, Patterns, Encode, Toivo

export code_dispatch, intentof


# ---- Method Interface -------------------------------------------------------
import Base.>=, Base.&
export Method, nomethod, MethodNode

type Method
    sig::Pattern
    bindings::Vector{Node}
    body::Union(Function,Nothing)
    hullT::Tuple

    Method(sig::Pattern, bs, body) = new(sig, bs, body,julia_signature_of(sig))
end

const nomethod = Method(Pattern(anything), Node[], nothing)

>=(x::Method, y::Method) = x.sig.intent >= y.sig.intent
#==(x::Method, y::Method) = x.sig.intent == y.sig.intent
#(&)(m::Method,  i::Intension) = Method(m.sig & Pattern(i), m.bindings, m.body)
(&)(m::Method,  i::Intension) = m.sig.intent & i

typealias MethodNode PartialOrder.Node{Method}
intentof(m::MethodNode) = m.value.sig.intent


# ---- Decision Tree ----------------------------------------------------------

abstract DNode

type Decision <: DNode
    intent::Intension
    pass
    fail
    seq::Vector

    Decision(intent::Intension, pass, fail) = new(intent, pass, fail)
end

type MethodCall <: DNode
    m::Method
    bind_seq::Vector
    bindings::Vector{Node}

    MethodCall(m::Method) = new(m)
end

type NoMethodNode <: DNode; end
const nomethodnode = NoMethodNode()

code_dispatch(top::MethodNode) = code_dispatch(top, ResultsDict())
function code_dispatch(top::MethodNode, pre_results::ResultsDict)
    dtree = build_dtree(top, subDAGof(top))

    seq_dispatch!(pre_results, dtree)
    code = code_dispatch(dtree)
end

# ---- create decision tree ---------------------------------------------------

firstitem(iter) = next(iter, start(iter))[1]

function build_dtree(top::MethodNode, ms::Set{MethodNode})
    if isempty(top.gt) || length(ms) == 1
        top.value.body === nothing ? nomethodnode : MethodCall(top.value)
    else        
        pivot = firstitem(top.gt & ms)
        below = subDAGof(pivot)
        pass = build_dtree(pivot, ms & below)
        fail = build_dtree(top,   ms - below)
        Decision(intentof(pivot), pass, fail)
    end    
end


# ---- seq_dispatch!: sequence decision tree ----------------------------------

seq_dispatch!(results::ResultsDict, d::DNode) = nothing
function seq_dispatch!(results::ResultsDict, m::MethodCall)
    s = Sequence(m.m.sig.intent, results) # shouldn't need an Intension...
    for node in values(m.m.sig.bindings);  sequence!(s, node)  end
    m.bind_seq = s.seq
    m.bindings = Node[results[node] for node in m.m.bindings]
end
function seq_dispatch!(results::ResultsDict, d::Decision)
    results_fail = copy(results)
    s = Sequence(d.intent, results)
    for g in guardsof(d.intent);  sequence!(s, Guard(g))  end
    d.seq = s.seq

    seq_dispatch!(results, d.pass)
    seq_dispatch!(results_fail, d.fail)
end


# ---- code_dispatch: decision tree -> dispatch code --------------------------

function code_dispatch(::NoMethodNode)
    :( error("No matching pattern method found") )
end
function code_dispatch(m::MethodCall)
    prebind = encoded(m.bind_seq)
    args = {resultof(node) for node in m.bindings}
    quote
        $(prebind...)
        $(quot(m.m.body))($(args...))
    end
end
function code_dispatch(d::Decision)
    pred = code_predicate(d.seq)
    pass = code_dispatch(d.pass)
    fail = code_dispatch(d.fail)
    code = :( if $pred; $pass; else; $fail; end )
    #length(pre) == 0 ? code : (quote; $(pre...); $code; end)
    code
end

end # module
