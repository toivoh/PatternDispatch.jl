
module Dispatch
import Base.add, Base.>=, Base.&
import PartialOrder
using PartialOrder, Patterns, Encode, Toivo
export MethodTable, Method, dispatch

abstract DNode

type Decision <: DNode
    intent::Intension
    pass
    fail
    seq::Vector

    Decision(intent::Intension, pass, fail) = new(intent, pass, fail)
end

type Method
    sig::Pattern
    body
end
>=(x::Method, y::Method) = x.sig.intent >= y.sig.intent


const nomethod = Method(Pattern(anything), nothing)
(&)(m::Method,  i::Intension) = Method(m.sig & Pattern(i), m.body)

type MethodCall <: DNode
    m::Method
    bind_seq::Vector
    bindings::Dict{Symbol,Node}

    MethodCall(m::Method) = new(m)
end

typealias MethodNode PartialOrder.Node{Method}
intentof(m::MethodNode) = m.value.sig.intent

type NoMethodNode <: DNode; end
const nomethodnode = NoMethodNode()

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

code_dispatch(top::MethodNode) = code_dispatch(top, ResultsDict())
function code_dispatch(top::MethodNode, pre_results::ResultsDict)
    dtree = build_dtree(top, subDAGof(top))

    seq_dispatch!(pre_results, dtree)
    code = code_dispatch(dtree)
end
function create_dispatch(mt::MethodTable)
    code = code_dispatch(mt.top)
    # todo: which eval?
    eval(:(let
            const f = $(mt.f)
            f($argsym...) = $code
        end))
end


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
        provide!(results, tupref(argnode, k), argsym)
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
    m.bindings = (Symbol=>Node)[name => results[node] 
                                for (name,node) in m.m.sig.bindings]
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
    binds = { :( $name = $(resultof(node))) for (name,node) in m.bindings }
    quote
        $(prebind...)
        $(binds...)
        $(m.m.body)
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
