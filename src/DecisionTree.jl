
module DecisionTree
import Base.==
using Meta, PartialOrder, Patterns, Encode, Dispatch

export code_dispatch, intentof


import PartialOrder
const PNode = PartialOrder.Node # todo: remove

code_dispatch{M}(top::PNode{M}) = code_dispatch(top, ResultsDict())
function code_dispatch{M}(top::PNode{M}, pre_results::ResultsDict)
    dtree = build_dtree(top, subDAGof(top))

    seq_dispatch!(pre_results, dtree)
    code = code_dispatch(dtree)
end


# ---- seq_dispatch!: sequence decision tree ----------------------------------

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
