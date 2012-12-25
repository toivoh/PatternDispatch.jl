
module Dispatch
import Base.add
import Nodes
using PartialOrder, Patterns, DecisionTree, Encode, Toivo
export MethodTable, Method, methodsof, show_dispatch

type MethodTable
    name::Symbol
    top::MethodNode
    f::Function
    compiled::Bool
    julia_methods::Dict{Tuple,Any}

    function MethodTable(name::Symbol) 
        f = eval(:(let
                $name(args...) = error("No matching pattern method found")
                $name
            end))
        mt = new(name, MethodNode(nomethod), f, false, (Tuple=>Any)[])
        eval(:(let
                const f = $f
                function f(args...)
                    create_dispatch($(quot(mt)))
                    $(quot(mt)).f(args...)
                end
            end))
        mt
    end
end

show_dispatch(mt::MethodTable, args...) = show_dispatch(OUTPUT_STREAM, mt, args...)
show_dispatch(io::IO, args...) = error("No method")
show_dispatch(io::IO, mt::MethodTable) = show_dispatch(io, mt, Tuple)
function show_dispatch(io::IO, mt::MethodTable, Ts::Tuple) 
    if !mt.compiled;  create_dispatch(mt);  end
    for (f_Ts, fdef) in mt.julia_methods
        if f_Ts <: Ts
            Base.show_unquoted(io, fdef)
            println(io)
        end
    end
end

function add(mt::MethodTable, m::Method)
    insert!(mt.top, MethodNode(m))
    
    methods = methodsof(mt)
    for mk in methods
        lb = m.sig.intent & mk.sig.intent
        if lb === naught; continue; end
        if any([ml.sig.intent == lb for ml in methods]) continue; end
        
        sig1 = suffix_bindings(m.sig,  "_A")
        sig2 = suffix_bindings(mk.sig, "_B")

        println("Warning: New @pattern method ", mt.name, sig1)
        println(" is ambiguous with ", mt.name, sig2)
        println(" Make sure ", mt.name, sig1&sig2, " is defined first")
    end

    # todo: only when necessary
    if mt.compiled;  create_dispatch(mt)  end
end

function methodsof(mt::MethodTable)
    ms = subDAGof(mt.top)
    [m.value for m in ms]
end

function create_dispatch(mt::MethodTable)
    mt.compiled = true
    eval(:(let
            const f = $(mt.f)
            f(args...) = error("No matching pattern method found")
        end))

    methods = methodsof(mt)
    actual_methods = filter(m->(m != nomethod), methods)
    hullTs = Set{Tuple}(Tuple[m.hullT for m in actual_methods]...)

    for hullT in hullTs;  create_dispatch(mt, methods, hullT);  end
end

ltT(S,T) = !(S==T) && (S<:T)
function create_dispatch(mt::MethodTable, methods::Vector{Method},hullT::Tuple)
    top = copyDAG(mt.top)

    # filter out too specific methods
    keep = Set{Method}(filter(m->!ltT(m.hullT, hullT), methods)...)
    @assert !isempty(keep)
    raw_filter!(top, keep)

    # filter out non-questions
    hull = intension(hullT)
    top = simplify!(top, hull)

#     @show hullT
#     @show tuple([node.value.sig for node in subDAGof(top)]...)
#     @show top.value.sig
#     println()
    
    # create dispatch code using given assumptions and args
    # todo: move some of this into DecisionTree
    results = ResultsDict()
    for pred in guardsof(hull);  preguard!(results, Guard(pred));  end
    argsyms = {gensym("arg") for k=1:length(hullT)}
    for (k, argsym) in enumerate(argsyms)
        provide!(results, Nodes.tupref(Nodes.argnode, k), argsym)
    end

    code = code_dispatch(top, results)
    args = {:($argsym::$(quot(T))) for (argsym,T) in zip(argsyms,hullT)}    
    fdef = :(function f($(args...))
            $code
        end)
    mt.julia_methods[hullT] = fdef

    eval(:(let
            const f = $(quot(mt.f))
            f($(args...)) = $code
        end))
end

end # module
