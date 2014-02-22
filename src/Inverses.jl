module Inverses
export code_invdef, setinverse
export LowerInv

using Base.Meta: quot, isexpr
import ..Common: emit!, calc!, branch!, finish!, reemit!
using ..Ops
using ..Recode: recodeinv, sinksym, code_arg, code_bind, qfinish!


function code_invdef(invsig, body)
    # should have exactly one argument to the inverse
    @assert length(invsig.args) == 2
    invarg = invsig.args[2]
    inv = invsig.args[1]
    @assert isexpr(inv, :macrocall, 2)
    @assert inv.args[1] === symbol("@inverse")
    sig = inv.args[2]
    @assert isexpr(sig, :call)
    @assert length(sig.args) >= 1
    fname = sig.args[1]::Symbol
    fargs = sig.args[2:end]
    
    fargnames = [(isexpr(farg, :(::)) ? farg.args[1] : farg)::Symbol for farg in fargs]

    # parse/recode body
    vars = Set{Symbol}()
    push!(vars, invarg)
    recbody = recodeinv(vars, body)
    for fargname in fargnames
        if !(fargname in vars)
            error("Argument $fargname never assigned in inverse function")
        end
    end
    rectuple = recodeinv(vars, :( ($(fargnames...),) ))

    reccode = isexpr(recbody, :block) ? recbody.args : [recbody]
    # NB: this code can not declare any locals at top level since several copies may be
    # emitted in one block by @patterns
    quote        
        # we need the let to protect later code from variables created in reccode, including fname
        nodeseq = $(esc( :( let
            $sinksym = $(quot(NodeSeq))()
            $invarg = $(code_arg())
            $(reccode...)
            $(code_bind(rectuple, :args))
            $qfinish!($sinksym)
            $sinksym
        end)))
        setinverse($(esc(fname)), $(length(fargs)), nodeseq)
        nothing
    end
end


immutable Node
    head::Head
    args::Vector{Int}
    Node(head::Head, args::Int...) = new(head, Int[args...])
end

immutable NodeSeq
    nodes::Vector{Node}
    bindings::Dict{Symbol,Int}
    NodeSeq() = new([Node(Arg())], (Symbol=>Int)[]) # ensure node 1 is Arg
end

function emit!(seq::NodeSeq, b::Binding, arg::Int)
    key = b.key
    @assert !haskey(seq.bindings, key)
    seq.bindings[key] = arg
    nothing
end
emit!(s::NodeSeq, head::Head, args::Int...) = (calc!(s, head, args...); nothing)

calc!(s::NodeSeq, head::Arg) = 1
calc!(s::NodeSeq, head::Arg, args::Int...) = error("Arg takes no arguments")
function calc!(s::NodeSeq, head::Head, args::Int...)
    push!(s.nodes, Node(head, args...))
    return length(s.nodes)
end


function reemit!(sink, seq::NodeSeq, argnode)
    n = length(seq.nodes)
    results = Array(Any, n)
    results[1] = argnode
    for k=2:n
        node = seq.nodes[k]
        head, args = node.head, [results[arg] for arg in node.args]
        if isa(head, Calc); results[k] = calc!(sink, head, args...)
        else;               emit!(sink, head, args...); results[k] = nothing
        end
    end
    [key => results[index] for (key, index) in seq.bindings]
end


const inverses = Dict{(Base.Callable, Int), NodeSeq}()

function setinverse(f::Base.Callable, nargs::Int, nodeseq::NodeSeq)
    if haskey(inverses, (f, nargs))
        println("Warning: replacing definition of (pattern) inverse function for function $f with $nargs arguments")
    end
    inverses[(f, nargs)] = nodeseq
end



immutable LowerInv{T}
    sink::T
end

branch!(c::LowerInv) = LowerInv(branch!(c.sink))
finish!(c::LowerInv) = LowerInv(finish!(c.sink))

emit!(c::LowerInv, head::Head, args...) = emit!(c.sink, head, args...)
calc!(c::LowerInv, head::Calc, args...) = calc!(c.sink, head, args...)

calc!(c::LowerInv, head::Inv, args...) = error("Inv takes a single argument")
function calc!(c::LowerInv, head::Inv, arg)
    if !haskey(inverses, (head.f, head.nargs))
        error("No inverse function defined for $(head.f) with $(head.nargs) arguments")
    end
    results = reemit!(c.sink, inverses[(head.f, head.nargs)]::NodeSeq, arg)
    results[:args]
end

function calc!(c::LowerInv, head::InvVector, arg)
    emit!(c.sink, TypeGuard(Vector), arg)
    n_node = calc!(c.sink, Call(length), arg)
    emit!(c.sink, EgalGuard(), n_node, calc!(c.sink, Source(head.nargs)))
    elements = [calc!(c.sink, Call(getindex), arg, calc!(c.sink, Source(k))) for k=1:head.nargs]
    calc!(c.sink, Call(tuple), elements...)
end


end # module
