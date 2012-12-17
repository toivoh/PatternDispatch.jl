include(find_in_path("PatternDispatch.jl"))

module TestShowPattern
using PatternDispatch

@show (@qpat 1)
@show (@qpat 1::Int)
@show (@qpat 1::Float64)

println()
@show (@qpat x::Any)
@show (@qpat ::Any)
@show (@qpat ::None)
@show (@qpat (x::None,y::Int))

println()
@show (@qpat x)
@show (@qpat ::Int)
@show (@qpat x::Int)
@show (@qpat x~y)
@show (@qpat x~y::Int)

println()
@show (@qpat (x,y))
@show (@qpat (x,y)::Tuple)
@show (@qpat z~(x::Int,1))

end 