
module DecisionTree
import Base.==
import PartialOrder
import Nodes.julia_signature_of
using Meta, PartialOrder, Patterns, Encode

export code_dispatch, intentof

const PNode = PartialOrder.Node


# ---- Method Interface -------------------------------------------------------
import Base.>=, Base.&
export Method, nomethod, MethodNode

type Method
    sig::Pattern
    bindings::Vector{Node}
    body::Union(Function,Nothing)
    body_ex
    hullT::Tuple
    id::Int

    function Method(sig::Pattern, bs, body, body_ex)
        new(sig, bs, body, body_ex, julia_signature_of(sig))
    end
end

const nomethod = Method(Pattern(anything), Node[], nothing, nothing)

>=(x::Method, y::Method) = x.sig.intent >= y.sig.intent
#==(x::Method, y::Method) = x.sig.intent == y.sig.intent
(&)(m::Method,  i::Intension) = m.sig.intent & i

domainof(m::Method) = m.sig.intent

typealias MethodNode PartialOrder.Node{Method}
domainof(m::MethodNode) = m.value.sig.intent



# ---- Decision Tree ----------------------------------------------------------

abstract DNode{M}

type Decision{M} <: DNode{M}
    domain
    pass
    fail
    methods::Vector{M}
    pre::Vector{Node}
    seq::Vector{Node}

    Decision(domain, pass, fail, ms) = new(domain, pass, fail, ms)
end
Decision{M}(dom, pass, fail, ms::Vector{M}) = Decision{M}(dom, pass, fail, ms)

type MethodCall{M} <: DNode{M}
    m::M
    bind_seq::Vector
    bindings::Vector{Node}

    MethodCall(m::M) = new(m)
end
MethodCall{M}(m::M) = MethodCall{M}(m)


type NoMethodNode <: DNode; end
const nomethodnode = NoMethodNode()

code_dispatch{M}(top::PNode{M}) = code_dispatch(top, ResultsDict())
function code_dispatch{M}(top::PNode{M}, pre_results::ResultsDict)
    dtree = build_dtree(top, subDAGof(top))

    seq_dispatch!(pre_results, dtree)
    code = code_dispatch(dtree)
end

# ---- create decision tree ---------------------------------------------------

function choose_pivot{M}(top::PNode{M}, ms::Set{PNode{M}})
    nmethods = length(ms)
    p_opt = nothing
    n_opt = nmethods+1
    for pivot in top.gt & ms
        below = ms & subDAGof(pivot)
        npass = length(below)
        nfail = nmethods - npass
        n = max(npass, nfail)
        if n < n_opt
            p_opt, n_opt = pivot, n
        end
    end
    p_opt::PNode{M}
end

function build_dtree{M}(top::PNode{M}, ms::Set{PNode{M}})
    if isempty(top.gt) || length(ms) == 1
        top.value.body === nothing ? nomethodnode : MethodCall(top.value)
    else        
        pivot = choose_pivot(top, ms)
        below = subDAGof(pivot)
        pass = build_dtree(pivot, ms & below)
        fail = build_dtree(top,   ms - below)

        methods = M[node.value for node in filter(node->has(ms, node), 
                                                  ordered_subDAGof(top))]
        Decision(domainof(pivot.value), pass, fail, methods)
    end    
end


# ---- seq_dispatch!: sequence decision tree ----------------------------------

function make_namer(methods::Vector{Method})
    (node::Node)->begin        
        for method in methods
            rb = method.sig.rev_bindings
            if has(rb, node)
                return symbol(string(rb[node], '_', method.id))
            end
        end
        nothing
    end
end

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


# ---- code_dispatch: decision tree -> dispatch code --------------------------

wrap(ex)       = ex
wrap(exprs...) = expr(:block, exprs...)

function code_dispatch(::NoMethodNode)
    :( error("No matching pattern method found") )
end
function code_dispatch(m::MethodCall)
    prebind = encoded(m.bind_seq)
    args = {resultof(node) for node in m.bindings}
    wrap(prebind...,
         expr(:call, quot(m.m.body), args...))
end
function code_dispatch(d::Decision)
    pre = encoded(d.pre)
    pred = code_predicate(d.seq)
    pass = code_dispatch(d.pass)
    fail = code_dispatch(d.fail)
    code = expr(:if, pred, pass, fail)
    wrap(pre..., code)
end

end # module
