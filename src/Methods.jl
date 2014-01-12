module Methods
export MethodTable, addmethod!, methodsof
export encode

import Base.>=
using ..PartialOrder
using ..Common: emit!, calc!, finish!, branch!, reemit!
using ..Ops: Arg, Call
using ..PatternGraphs.nevermatches
using ..Patterns
using ..Encode, ..Encode.Return
using ..Inverses


lowerinv(p::Pattern) = (p; q = Pattern(); reemit!(LowerInv(q), p); q)

type Method
    p_orig::Pattern
    p::Pattern
    f::Union(Function,Nothing)
    argnames::Vector{Symbol}
    id::Int
    body_ex

    function Method(p_orig::Pattern, f, names::Vector{Symbol}, body_ex)
        new(p_orig, lowerinv(p_orig), f, names, 0, body_ex)
    end
    Method(m::Method, id::Int) = new(m.p_orig, m.p, m.f, m.argnames, id, m.body_ex)
end

>=(m1::Method, m2::Method) = m1.p >= m2.p


typealias MethodNode PartialOrder.Node{Method}

empty_pattern() = (p = Pattern(); calc!(p, Arg()); p)

type MethodTable
    name::Symbol
    top::MethodNode
    num_methods::Int
    
    MethodTable(name::Symbol) = new(name, 
        MethodNode(Method(empty_pattern(), nothing, Symbol[], nothing)), 0)
end

methodsof(mt::MethodTable) = [node.value for node in subDAGof(mt.top)]

function addmethod!(mt::MethodTable, m::Method)
    if nevermatches(m.p.g)
        println("Warning: trying to add nevermatching method to function ", mt.name)
        return
    end

    m = Method(m, (mt.num_methods += 1))
    insert!(mt.top, MethodNode(m))

    methods = methodsof(mt)
    for mk in methods
        if mk === m;  continue  end
        lb = m.p.g & mk.p.g
        if nevermatches(lb); continue; end
        if any([ml.p.g == lb for ml in methods]) continue; end
        
        sig1 = Pattern(m.p_orig,  "_A")
        sig2 = Pattern(mk.p_orig, "_B")

        println("Warning: New @pattern method ", mt.name, sig1)
        println("         is ambiguous with   ", mt.name, sig2, '.')
        println("         Make sure ", mt.name, sig1 & sig2," is defined first.")
    end
end

function encode(mt::MethodTable)
    seq = CodeSeq()
    encode!(LowerInv(CachedCode(LowerTo(seq))), mt.top, subDAGof(mt.top))

    code = {}
    m = MatchCode(code)
    reemit!(m, seq)
    finish!(m)

    if mt.top.value.f === nothing
        push!(code, :( error($("No matching pattern found for $(mt.name)")) ))
    end
    :(
        function $(mt.name)($argsym...)
            $(code...)            
        end
     )        
end

function encode!(sink, top::MethodNode, ms::Set{MethodNode})
    m = top.value
    nodemap = reemit!(sink, m.p_orig.g)

    for pivot in intersect(top.gt, ms)
        sink_below = branch!(sink)
        ms_below = intersect(subDAGof(pivot), ms)
        encode!(sink_below, pivot, ms_below)
        setdiff!(ms, ms_below)        
    end

    args = [nodemap[m.p_orig.bindings[key]] for key in m.argnames]
    if m.f === nothing
        # todo: emit something?
        # This should only happen at the top?
    else
        emit!(sink, Return(), calc!(sink, Call(m.f), args...))
    end
    finish!(sink)
end

end # module
