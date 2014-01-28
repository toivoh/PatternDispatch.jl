module Encode
export LowerTo
export CodeSeq
export MatchCode, argsym
export CachedCode
export blockexpr

using Base.Meta
using ..Ops
using ..Patterns
import ..Common: emit!, calc!, branch!, finish!, reemit!

using ..DAGs, ..PatternDAGs


const argsym = :args  # gensym("args")


immutable BoolGuard <: Guard; end
immutable Return <: Head; end
immutable Ex <: Calc; ex; end

immutable LowerTo{T}
    sink::T
end

function emit_guard!(c::LowerTo, head::Calc, args...)
    emit!(c.sink, BoolGuard(), calc!(c.sink, head, args...))
end
source!(c, value) = calc!(c, Source(value))

emit!(c::LowerTo, head::Head, args...) = emit!(c.sink, head, args...)
calc!(c::LowerTo, head::Calc, args...) = calc!(c.sink, head, args...)

calc!(c::LowerTo, ::Arg)     = calc!(c.sink, Ex(argsym))
calc!(c::LowerTo, s::Source) = calc!(c.sink, Ex(quot(s.value)))
function calc!(c::LowerTo, t::TupleRef, arg)
    calc!(c.sink,Call(getindex),arg,source!(c,index_of(t)))
end

emit!(c::LowerTo, ::Never) = error("Should never have to lower Never()!")
emit!(c::LowerTo, ::EgalGuard, x, y) = emit_guard!(c, Call(is), x, y)
emit!(c::LowerTo, t::TypeGuard, x) = emit_guard!(c, Call(isa), x,source!(c,t.T))

branch!(c::LowerTo) = LowerTo(branch!(c.sink))


type Inst{H<:Head}
    head::H
    args::Vector{Inst}
    nrefs::Int
    result # also store suggested name before reemit, or nothing
    function Inst(head::H, args::Inst...)
        inst = new(head, Inst[args...], 0, nothing)
        for arg in args; arg.nrefs += 1; end
        inst
    end
end
Inst{H<:Head}(head::H, args::Inst...) = Inst{H}(head, args...)

immutable CodeSeq
    code::Vector{Inst}
    CodeSeq() = new(Inst[])
end

immutable Branch <: Head; seq::CodeSeq; end

branch!(c::CodeSeq) = (c2 = CodeSeq(); emit!(c, Branch(c2)); c2)
finish!(c::CodeSeq) = nothing

emit!(c::CodeSeq, b::Binding, arg::Inst) = (if arg.result === nothing; arg.result = b.key; end)
function emit!(c::CodeSeq, head::Head, args::Inst...)
    push!(c.code, Inst(head, args...)); nothing
end
function calc!(c::CodeSeq, head::Calc, args::Inst...)
    inst = Inst(head, args...); push!(c.code, inst); inst
end

function reemit!(sink, c::CodeSeq)
    for inst in c.code; reemit_inst!(sink, inst); end
end

resultof(ns::Vector{Inst}) = [n.result for n in ns]

reemit_inst!(sink, n::Inst) = emit!(sink, n.head, resultof(n.args)...)
function reemit_inst!{H<:Calc}(sink, n::Inst{H})
    result = calc!(sink, n.head, resultof(n.args)...)
    if !isa(n, Inst{Ex}) && n.nrefs >= 2; n.result = record!(sink, result, n.result)
    else                                  n.result = result
    end
end
function reemit_inst!(sink, n::Inst{Branch})
    sink2 = branch!(sink)
    reemit!(sink2, n.head.seq)
    finish!(sink2)
end



type MatchCode
    dest::Vector{Any}
    current::Vector{Any}
    pred
    MatchCode(dest) = new(dest, {}, true)
end

blockexpr(code::Vector) = length(code) == 1 ? code[1] : Expr(:block, code...)

function emit!(c::MatchCode, g::BoolGuard, pred)
    if c.pred === true
        append!(c.dest, c.current)
        c.pred = pred
    else
        push!(c.current, pred)
        pred = blockexpr(c.current)
        c.pred = :( $(c.pred) && $pred )
    end
    empty!(c.current)
end

branch!(c::MatchCode) = MatchCode(c.current)

function finish!(c::MatchCode)
    if c.pred === true; append!(c.dest, c.current)
    else; push!(c.dest, Expr(:if, c.pred, Expr(:block, c.current...)))
    end
    # This should return c to a fresh state; though we probably don't need that?
    c.pred = true; empty!(c.current)
end

record!(c::MatchCode, ex, ::Nothing)    = record!(c::MatchCode, ex)
record!(c::MatchCode, ex)               = record!(c::MatchCode, ex, gensym())
record!(c::MatchCode, ex, name::Symbol) = (push!(c.current, :( $name = $ex )); name)

emit!(c::MatchCode, b::Binding, arg) = push!(c.current, :( $(b.key) = $arg ))
emit!(c::MatchCode, r::Return, arg) = push!(c.current, :( return $arg ))

calc!(c::MatchCode, ex::Ex) = ex.ex
function calc!(c::MatchCode, op::Call, args...)
    if op.f === getindex;                    Expr(:ref, args...)
    elseif op.f === is && length(args) == 2; :( $(args[1]) === $(args[2]) )
    else;                                    :( $(quot(op.f))($(args...)) )
    end
end



immutable Result <: Head; result; end

Ops.keyof(op::Result) = Result  # Disregard result
# If two results are available, use either
Ops.meet(r1::Result, r2::Result) = r1

reskey(node::Node) = keyof(Result(nothing), node)
resultof(node::Node{Result}) = headof(node).result


immutable CachedCode
    sink
    state::Graph
end
CachedCode(sink) = CachedCode(sink, Graph())

branch!(c::CachedCode) = CachedCode(branch!(c.sink), branch!(c.state))
finish!(c::CachedCode) = (finish!(c.state); finish!(c.sink))

# can't keep the binding in state; shouldn't need it either
emit!(c::CachedCode, b::Binding, node::Node) = emit!(c.sink, b, resultof(c, node))

function emit!(c::CachedCode, ::EgalGuard, node1::Node, node2::Node)
    node1, node2 = primary_rep(node1), primary_rep(node2)
    if !(node1 === node2)
        emit!(c.sink,  EgalGuard(), resultof(c, node1), resultof(c, node2))
        emit!(c.state, EgalGuard(), node1, node2)
    end
end

function emit!(c::CachedCode, t::TypeGuard, node::Node)
    T = t.T
    key = tgkey(node)
    if (haskey(c.state, key) ? Tof(c.state[key]) : Any) <: T; return; end

    emit!(c.sink,  TypeGuard(T), resultof(c, node))
    emit!(c.state, TypeGuard(T), node)
    nothing
end

function resultof(c::CachedCode, node::Node)
    key = reskey(primary_rep(node))
    if !haskey(c.state, key); node = calc!(c, node.head, node.args...); end
    resultof(c.state[key])
end

function calc!(c::CachedCode, head::Calc, args::Node...)
    node = calc!(c.state, head, args...)
    key = reskey(node)
    if !haskey(c.state, key)
        result = calc!(c.sink, head, [resultof(c, arg) for arg in args]...)
        emit!(c.state, Result(result), node)
    end
    node
end

# should be ok not to cache Return
function emit!(c::CachedCode, head::Return, args::Node...)
    emit!(c.state, head, args...) # todo: do we need to emit it here?
    emit!(c.sink, head, [resultof(c, arg) for arg in args]...)
    nothing
end

end # module
