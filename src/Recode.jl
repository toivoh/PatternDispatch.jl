module Recode
export recode, recodeinv

using Base.Meta.quot
using ..Common: emit!, calc!, finish!
using ..Ops


const sinksym = gensym("sink")


const qemit!, qcalc!, qfinish!, qArg, qSource, qTupleRef, qCall, qInv, qBinding, qEgalGuard, qTypeGuard, qgetfield, qtuple = map(quot, (emit!, calc!, finish!, Arg, Source, TupleRef, Call, Inv, Binding, EgalGuard, TypeGuard, getfield, tuple))


sourcenode(valueex) = :( $qcalc!($sinksym, $qSource($valueex)) )

code_arg() = :( $qcalc!($sinksym, $qArg()) )
code_tupleref(nodesym::Symbol, k::Int) = :( $qcalc!($sinksym, $qTupleRef($k), $nodesym) )
code_invcall(nodesym::Symbol, fex) = :( $qcalc!($sinksym, $qInv($fex), $nodesym) )

code_bind(nodeex, key::Symbol) = :( $qemit!($sinksym, $qBinding($(quot(key))), $nodeex) )
code_equate(nex1,nex2) = :( $qemit!($sinksym, $qEgalGuard(), $nex1, $nex2) )

typeguard(sink, node, T) = (emit!(sink, TypeGuard(T), node); node)
const qtypeguard = quot(typeguard)
code_typeguard(nodeex, Tex) = :( $qtypeguard($sinksym, $nodeex, $Tex) )

code_call(fex, args) = :( $qcalc!($sinksym, $qCall($fex), $(args...)) )


type Rec
    code::Vector{Any}
    argnames::Set{Symbol}

    Rec() = new({}, Set{Symbol}())
end

function recode(ex, Pex)
    r = Rec()
    recode!(r, record!(r, code_arg()), ex)
    code = :( let $sinksym = $Pex
        $(r.code...) # r.code may use any identifiers
        $qfinish!($sinksym)
        $sinksym
    end )
    code, collect(Symbol, r.argnames)
end

function record!(r::Rec, ex)
    sym = gensym("t")
    push!(r.code, :( local $sym = $ex ))
    sym
end

function code_typeguard!(r::Rec, nodesym::Symbol, Tex)
    push!(r.code, code_typeguard(nodesym, Tex))
end

function recode_tuple!(r::Rec, nodesym::Symbol, args::Vector)
    code_typeguard!(r, nodesym, quot(NTuple{length(args)}))
    for (k,arg) in enumerate(args)
        recode!(r,
            record!(r, code_tupleref(nodesym, k)), arg)
    end
end

const tilde_macro_symbol = symbol("@~")
function recode!(r::Rec, nodesym::Symbol, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if (head === :call && nargs == 3 && args[1] === :~) || # old AST representation of ~
      (head === :macrocall && nargs == 3 && args[1] === tilde_macro_symbol) # new representation
        recode!(r, nodesym, args[2])
        recode!(r, nodesym, args[3])
    elseif head === :call
        invsym = record!(r, code_invcall(nodesym, args[1]))
        recode_tuple!(r, invsym, args[2:end])            
    elseif head === :(::)
        if nargs == 1
            code_typeguard!(r, nodesym, args[1])
        elseif nargs == 2
            code_typeguard!(r, nodesym, args[2])
            recode!(r, nodesym, args[1])
        else
            error("recode: Unrecognized expr = ", ex)
        end
    elseif head === :tuple
        recode_tuple!(r, nodesym, args)
    elseif head === :$ && nargs == 1
        push!(r.code, code_equate(nodesym, sourcenode(args[1])))
    else
        error("recode: Unrecognized expr = ", ex)
    end    
end

function recode!(r::Rec, nodesym::Symbol, name::Symbol)
    if name in r.argnames
        push!(r.code, code_equate(nodesym, name))
    else
        push!(r.code, code_bind(nodesym, name))
        push!(r.code, :( local $name = $nodesym ))
        push!(r.argnames, name)
    end
end
function recode!(r::Rec, nodesym::Symbol, ex)
    push!(r.code, code_equate(nodesym, sourcenode(quot(ex))))
end


# -------------------------------- recodeinv --------------------------------

 # Used to make sure that we actually get a Bool. todo: better way to tell the user
istrue(b::Bool) = b

recodeinv(vars::Set{Symbol}, ex::Symbol) = ex in vars ? ex : sourcenode(ex)
recodeinv(vars::Set{Symbol}, ex::QuoteNode) = sourcenode(ex)
recodeinv(vars::Set{Symbol}, ex) = sourcenode(ex)

function recodeinv(vars::Set{Symbol}, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head === :(::) && nargs == 2
        return code_typeguard(recodeinv(vars,args[1]), args[2])
    elseif head === :(=) && nargs == 2
        if !isa(args[1], Symbol)
            error("Unsupported lhs in inverse function, in ex = $ex")
        end
        push!(vars, args[1]::Symbol)
        :( $(args[1]) = $(recodeinv(vars, args[2])) )
    elseif head === :macrocall && nargs == 2 && args[1] == symbol("@guard")
        pred = recodeinv(vars, :( $(quot(istrue))($(args[2])) ))
        return code_equate(pred, sourcenode(true))
    elseif head === :(.) && nargs == 2
        return recodeinv(vars, :( $qgetfield($(args...)) ))
    elseif head === :tuple
        return recodeinv(vars, :( $qtuple($(args...)) ))
    elseif head === :call && nargs >= 1
        return code_call(args[1], [recodeinv(vars, arg) for arg in args[2:end]])
    elseif head === :block
        return Expr(:block, [recodeinv(vars, arg) for arg in args]...)
    elseif head === :line
        return ex
    elseif head === :quote
        return sourcenode(ex)
    else
        error("Unsupported expression in inverse function: ex = $ex")
    end
end


end # module
