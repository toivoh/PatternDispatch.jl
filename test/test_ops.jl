module TestOps
using PatternDispatch.Patterns, PatternDispatch.Recode

unordered(x,y) = !(x >= y || y >= x)

@assert (@ipat x) == (@ipat x)
@assert (@ipat x) == (@ipat y)
@assert unordered((@ipat x::Int), (@ipat x::AbstractString))
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
@assert (@ipat (x::Union{},z)) == naught
@assert (@ipat (x,y)::Tuple) == (@ipat (x,y))

end
