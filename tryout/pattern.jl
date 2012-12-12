
module Pattern

# -----------------------------------------------------------------------------

abstract Pattern

type PVar <: Pattern
    name::Symbol
end

type TypeAssert <: Pattern
    T
end

type Product <: Pattern
    factors::Vector{Pattern}
end

type TuplePat <: Pattern
    ps::Vector{Pattern}
end


# -----------------------------------------------------------------------------


abstract Node

# asserts that all args are egal
type EgalNode <: Node
    args::Vector{Node}
end

# asserts that valueof(v) is of type valueof(T)
type IsaNode <: Node
    v::Node
    T::Node
end

# asserts that valueof(t) is a tuple(ps...)
type TupleNode <: Node
    t::Node
    ps::Vector{Node}
end

type Atom <: Node
    value
end

type Var <: Node
    name::Symbol
end


# -----------------------------------------------------------------------------

abstract Value

type Atom{T} <: Value
    value::T
end
type Var <: Value
    name::Symbol
end


abstract Guard

# asserts that all args are egal
type Egal <: Guard
    args::Vector{Value}
end

# asserts that valueof(v)::valueof(T)
type Isa <: Guard
    v::Value
    T::Value
end

# asserts that valueof(t) is a tuple(ps...)
type TupleGuard <: Guard
    t::Value
    ps::Vector{Value}
end



end # module