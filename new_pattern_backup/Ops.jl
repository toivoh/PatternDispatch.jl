module Ops

export Head, Calc, Guard
export Binding, Arg, Source, TupleRef, Call, Inv, Never, EgalGuard, TypeGuard
export valueof, index_of, Tof
export keyof, meet

using Common.Head, Common.headof
import Common.keyof, Common.meet



abstract Calc <: Head
abstract Guard <: Head


immutable Binding <: Head; key::Symbol; end

immutable Arg      <: Calc; end
immutable Source   <: Calc; value;  end
immutable TupleRef <: Calc; k::Int; end
immutable Call     <: Calc; f::Base.Callable; end
immutable Inv      <: Calc; f::Base.Callable; end

immutable Never     <: Guard; end
immutable EgalGuard <: Guard; end
immutable TypeGuard <: Guard; T::Union(Type, Tuple); end # T must be a type

keyof(::TypeGuard) = TypeGuard  # Disregard T
meet(h1::TypeGuard, h2::TypeGuard) = TypeGuard(typeintersect(h1.T, h2.T))


valueof( op::Source)   = op.value
index_of(op::TupleRef) = op.k
Tof(     g::TypeGuard) = g.T

valueof(node)  = valueof(headof(node))
index_of(node) = index_of(headof(node))
Tof(node)      = Tof(headof(node))

end
