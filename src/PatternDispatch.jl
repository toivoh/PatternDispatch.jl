load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @immutable, @get!

macro immutable(ex)
    code_immutable(ex)
end

function code_immutable(ex)
    @expect is_expr(ex, :type, 2)
    sig, body = ex.args    
    typename = (is_expr(sig, :(<:), 2) ? sig.args[1] : sig)::Symbol 
    fields, types, sigs = Symbol[], {}, {}
    for arg in body.args
        if isa(arg, Symbol)
            push(fields, arg)
            push(types,  quot(Any))
            push(sigs, arg)
        elseif is_expr(arg, :(::), 2)
            push(fields, arg.args[1])
            push(types,  arg.args[2])            
            push(sigs, arg)
        end
    end
    
    instances = Dict()
    ast=esc(quote
        type $sig
            $(body.args...)
            $typename($(sigs...)) = @get!($(quot(instances)), ($(fields...),),
                                          new($(fields...)))
        end
    end)
#    @show ast
    ast
end


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



end # module
