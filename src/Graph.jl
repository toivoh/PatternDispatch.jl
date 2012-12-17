
module Graph
using Immutable

export Node, Value, Guard
export Arg, argsym, TupleRef, Bind, Egal, Isa, Never, never
export Pattern, nullpat


abstract Node
abstract Value <: Node
abstract Guard <: Node

type Arg <: Value; end
const argnode = Arg()
const argsym  = gensym("arg")

@immutable type TupleRef <: Value;  arg::Value; index::Int;    end
@immutable type Bind     <: Guard;  arg::Value; name::Symbol;  end
@immutable type Egal     <: Guard;  arg::Value; value;         end
@immutable type Isa      <: Guard;  arg::Value; typ;           end
type Never <: Guard; end
const never = Never()

type Pattern
    guards::Vector{Guard}
end

const nullpat = Pattern(Guard[never])


end # module