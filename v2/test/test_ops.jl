include(find_in_path("PatternDispatch/v2/PatternDispatch.jl"))

module TestOps
using PatternDispatch, PatternDispatch.Patterns

unordered(x,y) = !(x >= y || y >= x)

@assert (@ipat x) == (@ipat x)
@assert (@ipat x) == (@ipat y)
@assert unordered((@ipat x::Int), (@ipat x::String))
@assert (@ipat x) > (@ipat x::Int)
@assert (@ipat x::Int::Real) == (@ipat x::Int)
@assert (@ipat x) > (@ipat x::Int)

@assert (@ipat x) > (@ipat (x,y))
@assert unordered((@ipat x::Int), (@ipat (x,y)))
@assert (@ipat (x,y)::Number) == naught
@assert unordered((@ipat (x::Int,y)), (@ipat (x,y::Int)))
@assert (@ipat (x::Number,y)) > (@ipat (x::Int,y::Int))

@assert (@ipat 1::Float64) == naught
@assert (@ipat x::Any) == (@ipat x)
@assert (@ipat (x::None,z)) == naught
@assert (@ipat (x,y)::Tuple) == (@ipat (x,y))

end
