require("PatternDispatch.jl")

module TestExamples
using PatternDispatch

@pattern f(x) =  x
@pattern f(2) = 42

println(repr({f(x) for x=1:4}))

println()
show_dispatch(f)
#show_dispatch(f, (Int,))

@pattern egal(x, x) = true
@pattern egal(x, y) = false

@show egal(1, 1)
@show egal(1, 2)
@show egal(1, 1.0)
@show egal(1, "foo")
@show egal("foo", "foo")
@show (s = "foo"; egal(s, s))

@pattern f2((x, y::Int)) = x*y
@pattern f2([x, y::Int]) = x/y
@pattern f2(x)          = nothing

println()
@show f2((2,5))
@show f2((4,3))
@show f2([4,3])
@show f2((4,'a'))
@show f2({4,'a'})
@show f2(1)
@show f2("foo")
@show f2((1,))
@show f2((1,2,3))

@pattern f3(v~[x::Int, y::Int]) = {v,x*y}
@pattern f3(v) = nothing

println()
@show f3([3, 2])
@show f3({3, 2})
@show f3([3, 2.0])

@pattern f4(v~[v]) = true
@pattern f4([v])   = false

println()
@show f4([1])
@show f4([[1]])
@show f4([[[1]]])
@show (v = {1}; v[1] = v; f4(v))

@pattern f5($nothing) = 1
@pattern f5(x)        = 2

println()
@show f5(nothing)
@show f5(1)
@show f5(:x)
@show f5("foo")

println()
@pattern ambiguous((x,y),z) = 2
@pattern ambiguous(x,(1,z)) = 3

end # module
