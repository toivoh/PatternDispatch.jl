include(find_in_path("PatternDispatch.jl"))

module TestDispatch
using PatternDispatch

@show @qpat (x::Int)::Real
#@show simplify(@qpat (x::Int)::Real)
@show @qpat (x::Int)::Real
@show unbind(@qpat x::Int)

@show (@qpat (x::Int)) == (@qpat (x::Int)::Real)
@show (@qpat (x::Int)) == (@qpat (y::Int)::Real)
@show unbind(@qpat (x::Int)) == unbind(@qpat (y::Int)::Real)

@show (@qpat x) > (@qpat x::Int)
@show (@qpat x) <= (@qpat x::Int)

@show (@qpat x::Int::String) 

end # module
