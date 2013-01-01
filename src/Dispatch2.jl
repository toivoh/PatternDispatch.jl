
# uses:

# domainof(method)
# is_empty_domain(intent)
# signatureof(method, suffix)
# ismethod(method): false for nomethod
# hullof(method)

module Dispatch2
using PartialOrder
export addmethod!, simplify, build_dtree

methodsof{M}(top::Node{M}) = [node.value for node in subDAGof(top)]

function addmethod!{M}(top::Node{M}, name::Symbol, m::M)
    insert!(mt.top, Node(m))
    
    methods = methodsof(top)
    for mk in methods
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
    keep = Set{M}(filter(m->!(hullof(m) < hull), methodsof(top))...)
    @assert !isempty(keep)
    raw_filter!(top, keep)

    # filter out non-questions
    top = simplify!(top, hull)
end


# ---- Decision Tree ----------------------------------------------------------

abstract DNode

type Decision <: DNode
    domain
    pass
    fail
    methods::Vector

    Decision(domain, pass, fail, ms) = new(domain, pass, fail, ms)
end

type MethodCall <: DNode
    m
end

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

build_dtree(top::Node) = build_dtree(top, subDAGof(top))
function build_dtree{M}(top::Node{M}, ms::Set{Node{M}})
    if isempty(top.gt) || length(ms) == 1
        ismethod(top.value) ? MethodCall(top.value) : nomethodnode
    else        
        pivot = choose_pivot(top, ms)
        below = subDAGof(pivot)
        pass = build_dtree(pivot, ms & below)
        fail = build_dtree(top,   ms - below)

        methods = [node.value for node in filter(node->has(ms, node), 
                                                 ordered_subDAGof(top))]
        Decision(intentof(pivot), pass, fail, methods)
    end    
end

end # module