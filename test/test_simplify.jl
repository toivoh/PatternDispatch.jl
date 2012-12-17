include(find_in_path("PatternDispatch.jl"))

module TestDispatch
using PatternDispatch

@show @qpat (x::Int)::Real

@show (@qpat (x::Int)) == (@qpat (x::Int)::Real)
@show (@qpat (x::Int)) == (@qpat (y::Int)::Real)

@show (@qpat x) > (@qpat x::Int)
@show (@qpat x) <= (@qpat x::Int)

@show (@qpat x::Int::String) 

end # module
