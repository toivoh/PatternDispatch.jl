
module Dispatch
using ..PartialOrder
using ..PartialOrder: Node, insert!

export DNode, Decision, MethodCall, NoMethodNode
export domainof, signatureof, make_namer
export addmethod!, simplify, build_dtree

import ..Patterns
const INode = Patterns.Node # todo: remove!

## Method interface: ##

signatureof(method)  = error("unimplemented!")
domainof(method)     = error("unimplemented!")
is_empty_domain(dom) = error("unimplemented!")
hullof(method)       = error("unimplemented!")
make_namer(methods::Vector) = error("unimplemented!")


# ---- Method DAG manipulation ------------------------------------------------

methodsof{M}(top::Node{M}) = [node.value for node in subDAGof(top)]

function addmethod!{M}(top::Node{M}, name::Symbol, m::M)
    insert!(top, Node(m))
    
    methods = methodsof(top)
    for mk in methods
        if mk === m;  continue  end
        lb = domainof(m) & domainof(mk)
        if is_empty_domain(lb); continue; end
        if any([domainof(ml) == lb for ml in methods]) continue; end
        
        sig1 = signatureof(m,  "_A")
        sig2 = signatureof(mk, "_B")

        println("Warning: New @pattern method ", name, sig1)
        println("         is ambiguous with   ", name, sig2, '.')
        println("         Make sure ", name, sig1 & sig2," is defined first.")
    end
end

function simplify{M}(top::Node{M}, hull)
    top = copyDAG(top)

    # filter out too specific methods
    keep = Set{M}(filter(m->!(hullof(m) < hull), methodsof(top)))
    @assert !isempty(keep)
    raw_filter!(top, keep)

    # filter out non-questions
    top = simplify!(top, hull)
end

simplify!{T}(n::Node{T}, domain) = simplify!(Dict{Node{T},Node{T}}(), n, domain)
function simplify!{T}(subs::Dict{Node{T},Node{T}}, node::Node{T}, domain)
    if haskey(subs, node);  return subs[node]  end
    ndom = node.value & domain
    for child in node.gt
        if ndom == child.value & domain
            return subs[node] = simplify!(child, domain)
        end
    end

    node.gt = Set{Node{T}}([simplify!(child, domain) for child in node.gt])
    subs[node] = node
end


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
    for pivot in intersect(top.gt, ms)
        below = intersect(ms, subDAGof(pivot))
        npass = length(below)
        nfail = nmethods - npass
        n = max(npass, nfail)
        if n < n_opt
            p_opt, n_opt = pivot, n
        end
    end
    p_opt::Node{M}
end

build_dtree(top::Node) = build_dtree(top, subDAGof(top))
function build_dtree{M}(top::Node{M}, ms::Set{Node{M}})
    if isempty(top.gt) || length(ms) == 1
        top.value.body === nothing ? nomethodnode : MethodCall(top.value)
    else        
        pivot = choose_pivot(top, ms)
        below = subDAGof(pivot)
        pass = build_dtree(pivot, intersect(ms, below))
        fail = build_dtree(top,   setdiff(ms, below))

        methods = M[node.value for node in filter(node->(node in ms), 
                                                  ordered_subDAGof(top))]
        Decision(domainof(pivot.value), pass, fail, methods)
    end    
end

end # module
