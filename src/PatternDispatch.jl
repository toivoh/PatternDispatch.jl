load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @immutable, @get!

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



end # module
