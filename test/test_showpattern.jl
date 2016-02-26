module TestShowPattern
using PatternDispatch.Recode

@show (@qpat 1)
@show (@qpat 1::Int)
@show (@qpat 1::Float64)

println()
@show (@qpat x::Any)
@show (@qpat ::Any)
@show (@qpat ::Union{})
@show (@qpat (x::Union{},y::Int))

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