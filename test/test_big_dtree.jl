include(find_in_path("PatternDispatch.jl"))

module TestBigDTree
using PatternDispatch

@pattern f(1,1) = 11
@pattern f(1,2) = 12
@pattern f(2,1) = 21
@pattern f(2,2) = 21
@pattern f(1,y::Int) = 1
@pattern f(2,y::Int) = 2
@pattern f(x::Int,1) = 1
@pattern f(x::Int,2) = 2
@pattern f(x::Int,y::Int) = 0

show_dispatch(f)

end # module
