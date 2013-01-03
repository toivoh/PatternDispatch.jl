
module Dispatch
using Meta, PartialOrder

export DNode, Decision, MethodCall, NoMethodNode, build_dtree
export domainof, make_namer

import Patterns
const INode = Patterns.Node # todo: remove!

## Method interface: ##

domainof(method) = error("unimplemented!")
make_namer(methods::Vector) = error("unimplemented!")


# ---- Decision Tree ----------------------------------------------------------

abstract DNode{M}

type Decision{M} <: DNode{M}
    domain
    pass::DNode
    fail::DNode
    methods::Vector{M}
    pre::Vector{INode}
    seq::Vector{INode}

    Decision(domain, pass, fail, ms) = new(domain, pass, fail, ms)
end
Decision{M}(dom, pass, fail, ms::Vector{M}) = Decision{M}(dom, pass, fail, ms)

type MethodCall{M} <: DNode{M}
    m::M
    bind_seq::Vector
    bindings::Vector{INode}

    MethodCall(m::M) = new(m)
end
MethodCall{M}(m::M) = MethodCall{M}(m)

type NoMethodNode <: DNode; end
const nomethodnode = NoMethodNode()


# ---- create decision tree ---------------------------------------------------

function choose_pivot{M}(top::Node{M}, ms::Set{Node{M}})
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
    p_opt::Node{M}
end

function build_dtree{M}(top::Node{M}, ms::Set{Node{M}})
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

end # module
