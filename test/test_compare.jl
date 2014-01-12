module TestCompare

using PatternDispatch.Patterns

unordered(x,y) = !(x >= y || y >= x)

@assert (@qpat x) == (@qpat x)
@assert (@qpat x) == (@qpat y)
@assert unordered((@qpat x::Int), (@qpat x::String))
@assert (@qpat x) > (@qpat x::Int)
@assert (@qpat x::Int::Real) == (@qpat x::Int)

@assert (@qpat x) > (@qpat (x,y))
@assert unordered((@qpat x::Int), (@qpat (x,y)))
@assert (@qpat (x,y)::Number) == (@qpat ::None)
@assert unordered((@qpat (x::Int,y)), (@qpat (x,y::Int)))
@assert (@qpat (x::Number,y)) > (@qpat (x::Int,y::Int))

@assert (@qpat 1::Float64) == (@qpat ::None)
@assert (@qpat x::Any) == (@qpat x)
@assert (@qpat (x::None,z)) == (@qpat ::None)
@assert (@qpat (x,y)::Tuple) == (@qpat (x,y))

@assert (@qpat (x,x)) < (@qpat (x,y))
@assert unordered((@qpat (x,x)), (@qpat (x,y::Int)))
@assert (@qpat (x::Int,x::Real)) == (@qpat (y,y::Int))
@assert (@qpat x~(x,)) < (@qpat x::Tuple)

@assert (@qpat 1) < (@qpat ::Int)
@assert unordered((@qpat 1), (@qpat ::String))
@assert (@qpat 1) == (@qpat 1::Integer)


f(x) = x

@assert (@qpat f(x)) == (@qpat f(x))
@assert (@qpat f(x)) >= (@qpat f(x::Int))
@assert unordered((@qpat f(x::Int,y)), (@qpat f(x,y::Int)))

end # module
