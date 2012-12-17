include(find_in_path("PatternDispatch.jl"))

module TestAmbWarning
using PatternDispatch

@pattern f(x::Int, y) = 1
@pattern f(x, y::Int) = 2

end