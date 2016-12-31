module TestExamples
using PatternDispatch

@pattern f(x) =  x
@pattern f(2) = 42

println(repr([f(x) for x=1:4]))

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
@show f2([4,'a'])
@show f2(1)
@show f2("foo")
@show f2((1,))
@show f2((1,2,3))

@pattern f3(v~[x::Int, y::Int]) = [v,x*y]
@pattern f3(v) = nothing

println()
@show f3([3, 2])
@show f3([3, 2])
@show f3([3, 2.0])

@pattern f4(v~[v]) = true
@pattern f4([v])   = false

println()
@show f4([1])
@show f4([[1]])
@show f4([[[1]]])
@show (v = [[]]; v[1] = v; f4(v))


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


type MyType
    x
    y
end
@pattern function (@inverse MyType(x, y))(mt)
    mt::MyType
    x = mt.x
    y = mt.y
end

@pattern f6(MyType(x, y)) = (x,y)
@pattern f6(x)            = nothing

println()
@show f6(MyType(5,'x'))
@show f6(11)

MyType(x) = MyType(x, x)
@pattern function (@inverse MyType(x))(mt)
    mt::MyType
    x = mt.x
    y = mt.y
    x ~ y
end

@pattern f7(MyType(x))   = (1,x)
@pattern f7(MyType(x,y)) = (2,x,y)

println()
@show f7(MyType('a','a'))
@show f7(MyType('a','b'))


two_times_int(x::Int) = (@assert (typemin(Int)>>1) <= x <= (typemax(Int)>>1); 2x)
@pattern function (@inverse two_times_int(x))(y)
    y::Int
    @guard iseven(y)
    x = y >> 1
end

@pattern f8(x::Int, y::Int)           = (x,y)
@pattern f8(x::Int, two_times_int(x)) = x

println()
@show f8(3,5)
@show f8(3,6)
@show f8(4,8)


odd() = error() # conceptually returns all odd integers
@pattern function (@inverse odd())(x)
    x::Integer
    @guard isodd(x)
end

@pattern f9(odd(),     odd())     = "Both odd"
@pattern f9(odd(),     ::Integer) = "One odd"
@pattern f9(::Integer, odd())     = "One odd"
@pattern f9(::Integer, ::Integer) = "Both even"

println()
@show f9(3,5)
@show f9(3,6)
@show f9(4,8)


end # module
