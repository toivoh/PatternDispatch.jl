module TestExamples
using PatternDispatch

@pattern f(x) =  x
@pattern f(2) = 42

println(Any[f(x) for x=1:4])

println()
show_dispatch(f)
show_dispatch(f, (Int,))

@pattern f2((x,y::Int)) = x*y
@pattern f2([x,y::Int]) = x/y
@pattern f2(x)          = nothing

println()
@show f2((2,5))
@show f2((4,3))
@show f2([4,3])
@show f2((4,'a'))
@show f2(Any[4,'a'])
@show f2(1)
@show f2("foo")
@show f2((1,))
@show f2((1,2,3))

@pattern f3(v~[x::Int, y::Int]) = Any[v,x*y]
@pattern f3(v) = nothing

println()
@show f3([3, 2])
@show f3(Any[3, 2])
@show f3([3, 2.0])


@pattern f4($nothing) = 1
@pattern f4(x)        = 2

println()
@show f4(nothing)
@show f4(1)
@show f4(:x)
@show f4("foo")

println()
@pattern ambiguous((x,y),z) = 2
@pattern ambiguous(x,(1,z)) = 3

end # module
