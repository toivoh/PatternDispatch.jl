require("PatternDispatch.jl")

module TestShowDispatch
using PatternDispatch

# @pattern f(x::Int) = x^2
# @pattern f(3)      = 3
# @pattern f(x~::AbstractString) = 5

@pattern f(x,y) = 1
@pattern f(1,y) = 2
@pattern f(1,2) = 3

println("==== Full dispatch: ====")
show_dispatch(f)

println("\n==== Dispatch for (Int,Any): ====")
show_dispatch(f, (Int,Any))

end
