include(find_in_path("PatternDispatch.jl"))

module TestNamedNodes
using PatternDispatch

@pattern f((1,2))           = 3
@pattern f((x::Int,2))      = 2
@pattern f((1,y::Int))      = 1
@pattern f((x::Int,y::Int)) = x*y

show_dispatch(f)

end # module
