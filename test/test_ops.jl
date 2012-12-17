include(find_in_path("PatternDispatch.jl"))

module TestOps
using PatternDispatch, PatternDispatch.Graph

unordered(x,y) = !(x >= y || y >= x)

@assert (@qpat x) == (@qpat x)
@assert (@qpat x) == (@qpat y)
@assert unordered((@qpat x::Int), (@qpat x::String))
@assert (@qpat x) > (@qpat x::Int)
@assert (@qpat x::Int::Real) == (@qpat x::Int)
@assert (@qpat x) > (@qpat x::Int)

@assert (@qpat x) > (@qpat (x,y))
@assert unordered((@qpat x::Int), (@qpat (x,y)))
@assert (@qpat (x,y)::Number) == nullpat
@assert unordered((@qpat (x::Int,y)), (@qpat (x,y::Int)))
@assert (@qpat (x::Number,y)) > (@qpat (x::Int,y::Int))

@assert (@qpat 1::Float64) == nullpat
@assert (@qpat x::Any) == (@qpat x)
@assert (@qpat (x::None,z)) == nullpat
@assert (@qpat (x,y)::Tuple) == (@qpat (x,y))

end