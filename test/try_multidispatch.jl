include(find_in_path("PatternDispatch.jl"))

module TryMultiDispatch
using PatternDispatch.Patterns, PatternDispatch.Recode

abstract DNode

type Decision <: DNode
    intent::Intension
    pass
    fail
end

type Method <: DNode
    sig::Pattern
    body
end

type NoMethod <: DNode; end
const nomethod = NoMethod()

m1 = Method((@qpat (x::Int,)),    :1)
m2 = Method((@qpat (x::String,)), :2)
m3 = Method((@qpat (x,)),         :3)

dc = Decision(m2.sig.intent, m2, m3)
db = Decision(m1.sig.intent, m1, dc)
da = Decision(m3.sig.intent, db, nomethod)


function code_dispatch(results::Dict{Node,Any}, ::NoMethod)
    :( error("No matching pattern method found") )
end
function code_dispatch(results::Dict{Node,Any}, m::Method)
    bind = code_bind(results, m.sig.bindings)
    quote
        $(bind...)
        $(m.body)
    end
end
function code_dispatch(results::Dict{Node,Any}, d::Decision)
    results_fail = copy(results)
    pre, pred = code_match(results, d.intent)
    pass = code_dispatch(results, d.pass)
    fail = code_dispatch(results_fail, d.fail)
    code = :( if $pred; $pass; else; $fail; end )
    length(pre) == 0 ? code : (quote; $(pre...); $code; end)
end

function code_bind(results::Dict{Node,Any}, bindings::Dict{Symbol,Node})
    
end
function code_match(results::Dict{Node,Any}, intent::Intension)
    for g in guardsof(intent)
        
    end
    pre, pred
end


# code_bind
# code_match

end # module
