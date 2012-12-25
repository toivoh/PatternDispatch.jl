include(find_in_path("PatternDispatch.jl"))

module TestShowDispatch
using PatternDispatch

# @pattern f(x::Int) = x^2
# @pattern f(3)      = 3
# @pattern f(x~::String) = 5

@pattern f(x::Int,y::Int) = 1
@pattern f(1,y::Int) = 2
@pattern f(1,2) = 3

show_dispatch(f)

end