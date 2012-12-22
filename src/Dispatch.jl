
module Dispatch
import Base.add, Base.>=, Base.&
using Patterns, Encode, Toivo
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

const nomethod = Method(Pattern(anything), nothing)

type MethodCall <: DNode
    m::Method
    bind_seq::Vector
    bindings::Dict{Symbol,Node}

    MethodCall(m::Method) = new(m)
end

type MethodNode
    m::Method
    gt::Set{MethodNode}
end
MethodNode(m) = MethodNode(m, Set{MethodNode}())

>=(x::MethodNode, y::MethodNode) = intentof(x) >= intentof(y)

type NoMethodNode <: DNode; end
const nomethodnode = NoMethodNode()

intentof(m::MethodNode) = m.m.sig.intent

# (&)(m::Method,  i::Intension) = Method(m.sig & Pattern(i), m.body)
# (&)(m::NoMethodNode, ::Intension) = nomethodnode

type MethodTable
    name::Symbol
    top::MethodNode
    f::Function

    function MethodTable(name::Symbol) 
        mt = new(name, MethodNode(nomethod))
        mt.f = rebuilder(mt)
        mt
    end
end

rebuilder(mt::MethodTable) = (args...)->begin
        mt.f = create_dispatch(mt)
        mt.f(args...)
    end

dispatch(mt::MethodTable, args) = mt.f(args...)

function add(mt::MethodTable, m::Method)
    insert!(mt.top, MethodNode(m))
    mt.f = rebuilder(mt)
end

function code_dispatch(mt::MethodTable)
    dtree = build_dtree(mt.top, subtreeof(mt.top))

    seq_dispatch!(ResultsDict(), dtree)
    code = code_dispatch(dtree)
    fdef = :(($argsym...)->$code)    
end
create_dispatch(mt::MethodTable) = eval(code_dispatch(mt)) # todo: which eval?


# function code_dispatch2(mt::MethodTable)
#     ms = subtreeof(mt.top)
#     tups = Set{Tuple}({julia_signature_of(m) for m in ms})
#     for tup in tups
#         code_dispatch(mt, ms, tup)
#     end
# end

# function code_dispatch(mt::MethodTable, ms::Set{MethodNode}, tup::Tuple)
#     # create new method nodes
#     intent = julia_intension(tup)
#     ms = {MethodNode(m.m & intent) for m in ms}
#     # create new method DAG
# #    top = MethodNode
#     # todo: reuse bodies!    
    
# end



# ---- update method DAG ------------------------------------------------------

insert!(at::MethodNode, m::MethodNode) = insert!(Set{MethodNode}(), at, m)
function insert!(seen::Set{MethodNode}, at::MethodNode, m::MethodNode)
    if has(seen, at); return; end
    add(seen, at)
    if m >= at
        if at >= m 
            at.m = m.m  # at == m
            return true
        end
        # m > at
        add(m.gt, at)
        at_above_m = false
    else
        at_above_m = any([insert!(seen, below, m) for below in at.gt])
    end
    if !at_above_m
        if at >= m
            del_each(at.gt, at.gt & m.gt)
            add(at.gt, m)
            at_above_m = true
        end
    end
    at_above_m
end


# ---- create decision tree ---------------------------------------------------

firstitem(iter) = next(iter, start(iter))[1]

subtreeof(m::MethodNode) = (sub = Set{MethodNode}(); addsubtree!(sub, m); sub)
function addsubtree!(seen::Set{MethodNode}, m::MethodNode)
    if has(seen, m); return; end
    add(seen, m)
    for below in m.gt; addsubtree!(seen, below); end       
end

function build_dtree(top::MethodNode, ms::Set{MethodNode})
    if isempty(top.gt) || length(ms) == 1
        top.m.body === nothing ? nomethodnode : MethodCall(top.m)
    else        
        pivot = firstitem(top.gt & ms)
        below = subtreeof(pivot)
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
