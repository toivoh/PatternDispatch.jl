

abstract Action
type Decision{T<:Action}
    guards::Vector{Guard}
    action::T
end

type Branch <: Action
    pass::Decision
    fail::Decision
end

type Method <: Action
    args::Vector{Value}
    f::Function
end

code_pass(results::Dict{Node,Any}, a::Branch) = code_dispatch(results, a.pass)
code_fail(results::Dict{Node,Any}, a::Branch) = code_dispatch(results, a.fail)

function code_pass(results::Dict{Node,Any}, a::Method)
    expr(:call, a.f, {evaluate!(results, arg) for arg in a.args}...)
end
code_fail(::Dict{Node,Any}, ::Method) = :(error("no matching pattern found"))

function code_dispatch(results::Dict{Node,Any}, d::Decision)
    pred = quot(true)
    results_fail = copy(results)
    for g in d.guards
        ex = evaluate!(results, g)
        pred = pred == quot(true) ? ex : (:($pred && $ex))
    end
    if pred == quot(true)
        code_pass(results, d.action)
    else
        pass = code_pass(results,      d.action)
        fail = code_fail(results_fail, d.action)
        :( $ex ? $pass : $fail )
    end
end