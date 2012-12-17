
module Graph
import Base.&
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


(&)(e::Egal, f::Egal)= (@assert e.arg===f.arg; e.value===f.value ?   e : never)
(&)(e::Egal, t::Isa) = (@assert e.arg===t.arg; isa(e.value, t.typ) ? e : never)
(&)(t::Isa, e::Egal) = e & t
function (&)(s::Isa, t::Isa) 
    @assert s.arg===t.arg
    T = tintersect(s.typ, t.typ)
    T === None ? never : Isa(s.arg, T)
end

end # module
