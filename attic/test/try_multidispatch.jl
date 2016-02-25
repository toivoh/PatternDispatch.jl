module TryMultiDispatch
import Base.>=, Base.push!
using PatternDispatch.Patterns, PatternDispatch.Recode, PatternDispatch.Dispatch

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

type MethodCall <: DNode
    m::Method
    bind_seq::Vector
    bindings::Dict{Symbol,Node}

    MethodCall(m::Method) = new(m)
end

type MethodNode
    m
    gt::Set{MethodNode}
end
MethodNode(m) = MethodNode(m, Set{MethodNode}())

>=(x::MethodNode, y::MethodNode) = intentof(x) >= intentof(y)

type NoMethod <: DNode; end
const nomethod = NoMethod()

intentof(m::Method)     = m.sig.intent
intentof(m::MethodNode) = intentof(m.m)
intentof(::NoMethod)    = anything

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

function push!(mt::MethodTable, m::Method)
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


# ---- update method DAG ------------------------------------------------------

insert!(at::MethodNode, m::MethodNode) = insert!(Set{MethodNode}(), at, m)
function insert!(seen::Set{MethodNode}, at::MethodNode, m::MethodNode)
    if has(seen, at); return; end
    push!(seen, at)
    if m >= at
        if at >= m 
            at.m = m.m  # at == m
            return true
        end
        # m > at
        push!(m.gt, at)
        at_above_m = false
    else
        at_above_m = any([insert!(seen, below, m) for below in at.gt])
    end
    if !at_above_m
        if at >= m
            del_each(at.gt, m.gt)
            push!(at.gt, m)
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
    push!(seen, m)
    for below in m.gt; addsubtree!(seen, below); end       
end

function build_dtree(top::MethodNode, ms::Set{MethodNode})
    if isempty(top.gt) || length(ms) == 1
        isa(top.m, NoMethod) ? nomethod : MethodCall(top.m)
    else        
        pivot = firstitem(top.gt & ms)
        below = subtreeof(pivot)
        pass = build_dtree(pivot, ms & below)
        fail = build_dtree(top,   ms - below)
        Decision(intentof(pivot), pass, fail)
    end    
end


# ---- seq_dispatch! ----------------------------------------------------------

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

function code_dispatch(::NoMethod)
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

# ---- test code ----

m1 = Method((@qpat (x::Int,)),    :1)
m2 = Method((@qpat (x::String,)), :2)
m3 = Method((@qpat (x,)),         :3)

# node1 = MethodNode(m1, Set{MethodNode}())
# node2 = MethodNode(m2, Set{MethodNode}())
# node3 = MethodNode(m3, Set{MethodNode}(node1, node2))
# top   = MethodNode(nomethod, Set{MethodNode}(node3))
# mnodes = Set{MethodNode}(top, node1, node2, node3)

# dc = Decision(m2.sig.intent, MethodCall(m2), MethodCall(m3))
# db = Decision(m1.sig.intent, MethodCall(m1), dc)
# da = Decision(m3.sig.intent, db, nomethod)

# top = MethodNode(nomethod)
# for m in [m3,m2,m1];  insert!(top, MethodNode(m))  end
# mnodes = subtreeof(top)

# dtree = build_dtree(top, mnodes)

# seq_dispatch!(ResultsDict(), dtree)
# code = code_dispatch(dtree)
# println(code)
# fdef = :(($argsym...)->$code)

# f = eval(fdef)

mt = MethodTable(:f)
for m in [m3,m2,m1];  push!(mt, m)  end

@assert mt.f(5)     == 1
@assert mt.f("foo") == 2
@assert mt.f(5.0)   == 3

end # module
