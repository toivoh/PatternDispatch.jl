include(find_in_path("PatternDispatch.jl"))

module TryMultiDispatch
using PatternDispatch.Patterns, PatternDispatch.Recode, PatternDispatch.Dispatch

abstract DNode

type Decision <: DNode
    intent::Intension
    pass
    fail
    seq::Vector

    Decision(intent::Intension, pass, fail) = new(intent, pass, fail)
end

type Method <: DNode
    sig::Pattern
    body
    bind_seq::Vector
    bindings::Dict{Symbol,Node}

    Method(sig::Pattern, body) = new(sig, body)
end

type NoMethod <: DNode; end
const nomethod = NoMethod()

m1 = Method((@qpat (x::Int,)),    :1)
m2 = Method((@qpat (x::String,)), :2)
m3 = Method((@qpat (x,)),         :3)

dc = Decision(m2.sig.intent, m2, m3)
db = Decision(m1.sig.intent, m1, dc)
da = Decision(m3.sig.intent, db, nomethod)


seq_dispatch!(results::ResultsDict, d::DNode) = nothing
function seq_dispatch!(results::ResultsDict, m::Method)
    s = Sequence(m.sig.intent, results) # shouldn't need an Intension...
    for node in values(m.sig.bindings);  sequence!(s, node)  end
    m.bind_seq = s.seq
    m.bindings = (Symbol=>Node)[name => results[node] 
                                for (name,node) in m.sig.bindings]
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
function code_dispatch(m::Method)
    prebind = encoded(m.bind_seq)
    binds = { :( $name = $(resultof(node))) for (name,node) in m.bindings }
    quote
        $(prebind...)
        $(binds...)
        $(m.body)
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

seq_dispatch!(ResultsDict(), da)
code = code_dispatch(da)
show(code)


end # module
