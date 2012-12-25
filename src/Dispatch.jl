
module Dispatch
import Base.add
import Nodes
using PartialOrder, Patterns, DecisionTree, Encode, Toivo
export MethodTable, Method, methodsof

type MethodTable
    name::Symbol
    top::MethodNode
    f::Function
    compiled::Bool

    function MethodTable(name::Symbol) 
        f = eval(:(let
                $name(args...) = error("No matching pattern method found")
                $name
            end))
        mt = new(name, MethodNode(nomethod), f, false)
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

function add(mt::MethodTable, m::Method)
    insert!(mt.top, MethodNode(m))
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
    fdef = quote
        function f($(args...))
            $code
        end
    end
#   @show fdef

    eval(:(let
            const f = $(mt.f)
            f($(args...)) = $code
        end))
end

end # module
