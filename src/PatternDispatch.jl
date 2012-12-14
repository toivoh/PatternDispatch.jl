load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @immutable, @get!
export @pattern

include(find_in_path("PatternDispatch/src/immutable.jl"))


abstract Node
abstract Value <: Node
abstract Guard <: Node

type Arg      <: Value; end
const argnode = Arg()

@immutable type TupleRef   <: Value;  arg::Value; index::Int;    end
@immutable type Bind       <: Guard;  arg::Value; name::Symbol;  end
@immutable type Egal       <: Guard;  arg::Value; value;         end
@immutable type TypeAssert <: Guard;  arg::Value; typ;           end
@immutable type IsTuple    <: Guard;  arg::Value; n::Int;        end



type Pattern
    guards::Set{Guard}
end



macro pattern(ex)
    code_pattern(ex)
end

function code_pattern(ex)
    sig, body = split_fdef(ex)
    @expect is_expr(sig, :call)
    fname, args = sig.args[1], sig.args[2:end]
    psig = :($(args...),)
    @show sig
    p_ex = recode(psig)
    @show p_ex
    println()
    
end

type Recode
    code::Vector
    guards::Vector
    Recode() = new({}, {})
end

function recode(ex::Expr)
    r = Recode()
    recode(r, quot(Arg()), ex)
    quote
        $(r.code...)
        {$(r.guards...)}
    end
end

recode(c::Recode, arg, ex)         = push(c.guards, :(Egal($arg, $(quot(ex)))))
recode(c::Recode, arg, ex::Symbol) = push(c.guards, :(Bind($arg, $(quot(ex)))))
function recode(c::Recode, arg, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head === :(::)
        @assert 1 <= nargs <= 2
        if nargs == 1
            push(c.guards, :( TypeAssert($arg, $(args[1])) ))
        else
            push(c.guards, :( TypeAssert($arg, $(args[2])) ))
            recode(c, arg, args[1])
        end
    elseif head === :tuple
        push(c.guards, :( IsTuple($arg, $nargs) ))
        for (k, p) in enumerate(args)
            node = gensym("e$k")
            push(c.code, :( $node = TupleRef($arg, $k) ))
            recode(c, node, p)
        end
    elseif head === :call && args[1] == :~
        for p in args[2:end]; recode(c, arg, p); end
    else
        error("recode: unimplemented: ex = $ex")
    end
end


end # module
