
module Dispatch
import Base.add
import Nodes
using PartialOrder, Patterns, DecisionTree, Toivo
export MethodTable, Method, dispatch

type MethodTable
    name::Symbol
    top::MethodNode
    f::Function

    function MethodTable(name::Symbol) 
        f = eval(:(let
                $name(args...) = error("No matching pattern method found")
                $name
            end))
        new(name, MethodNode(nomethod), f)
    end
end

dispatch(mt::MethodTable, args) = mt.f(args...)

function add(mt::MethodTable, m::Method)
    insert!(mt.top, MethodNode(m))
    # todo: only when necessary
    create_dispatch(mt)
#    create_dispatch2(mt)
end

function create_dispatch(mt::MethodTable)
    code = code_dispatch(mt.top)
    # todo: which eval?
    eval(:(let
            const f = $(mt.f)
            f($(Nodes.argsym)...) = $code
        end))
end

# ---- Experimental cooperative dispatch ----

function create_dispatch2(mt::MethodTable)
    ms = subDAGof(mt.top)
    if mt.top.value.body === nothing
        del(ms, mt.top) # don't take the signature from nomethod
    end
    tups = Set{Tuple}({julia_signature_of(m.value.sig) for m in ms}...)
    for tup in tups
        create_dispatch(mt, ms, tup)
    end
end

function create_dispatch(mt::MethodTable, ms::Set{MethodNode}, tup::Tuple)
    # create new method nodes
    intent = julia_intension(tup)
    #methods = {m.value & intent for m in ms}
    methods = {filter(m->(!(m.sig.intent === naught)), 
                      {m.value & intent for m in ms})...}

    # create new method DAG
    top = MethodNode(Method(Pattern(intent), nothing))
    for m in methods;  insert!(top, MethodNode(m))  end
    
    # create dispatch code using given assumptions and args
    results = ResultsDict()
    for pred in guardsof(intent);  preguard!(results, Guard(pred));  end
    argsyms = {gensym("arg") for k=1:length(tup)}
    for (k, argsym) in enumerate(argsyms)
        provide!(results, Nodes.tupref(Nodes.argnode, k), Nodes.argsym)
    end

    code = code_dispatch(top, results)
    args = {:($argsym::$(quot(T))) for (argsym,T) in zip(argsyms,tup)}
    fdef = quote
        function f($(args...))
            $code
        end
    end
    @show fdef

    eval(:(let
            const f = $(mt.f)
            f($(args...)) = $code
        end))

    # todo: reuse bodies!    
    # todo: respect declaration order among collisions?
    
end


# ---- Decision Tree ----------------------------------------------------------


end # module
