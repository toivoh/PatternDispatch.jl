require("PatternDispatch.jl")

module TestExamples
using PatternDispatch

@pattern f(x) =  x
@pattern f(2) = 42

println({f(x) for x=1:4})

println()
show_dispatch(f)
show_dispatch(f, (Int,))

@pattern f2((x,y::Int)) = x*y
@pattern f2(x)          = nothing

println()
@show f2((2,5))
@show f2((4,3))
@show f2((4,'a'))
@show f2(1)
@show f2("foo")
@show f2((1,))
@show f2((1,2,3))

@pattern f3($nothing) = 1
@pattern f3(x)        = 2

println()
@show f3(nothing)
@show f3(1)
@show f3(:x)
@show f3("foo")

@pattern f4(t~(x,y)) = {t,x,y}

println()
@show f4((1,2))

println()
@pattern ambiguous((x,y),z) = 2
@pattern ambiguous(x,(1,z)) = 3

end # module
