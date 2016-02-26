module TestDispatch
using PatternDispatch

@pattern f(x::Int) = x^2
@pattern f(3)      = 3
@pattern f(x~::AbstractString) = 5

@assert [f(x) for x=1:4] == [1,4,3,16]
@assert f("foo") == 5


@pattern g((x,y)) = x*y
@pattern g(x)     = x

@assert g(11) == 11
@assert g((2,6)) == 12
@assert g([2,6]) == [2,6]


@pattern g2([x,y]) = x*y
@pattern g2(x)     = x

@assert g2(11) == 11
@assert g2([2,6]) == 12
@assert g2((2,6)) == (2,6)


@pattern h(x,(y,z))     = Any[x,y,z]
@pattern h((x,y),(z,w)) = Any[x,y,z,w]
@pattern h((x,y),z)     = Any[x,y,z]

@assert h((1,2),(3,4)) == [1,2,3,4]
@assert h(1,(2,3))     == [1,2,3]
@assert h((1,2),3)     == [1,2,3]
@assert h((1,2),[3,4]) == Any[1,2,[3,4]]


@pattern h2(x,[y,z])     = Any[x,y,z]
@pattern h2([x,y],[z,w]) = Any[x,y,z,w]
@pattern h2([x,y],z)     = Any[x,y,z]

@assert h2([1,2],[3,4]) == [1,2,3,4]
@assert h2(1,[2,3])     == [1,2,3]
@assert h2([1,2],3)     == [1,2,3]
@assert h2([1,2],(3,4)) == Any[1,2,(3,4)]


@pattern l(::Any)    = 1
@pattern l(::Number) = 2

@assert l(5) == l(5.0) == 2
@assert l(:x) == l("x") == l([1,2]) == 1


@pattern m()        = 1
@pattern m(x)       = 2
#@pattern m(args...) = 3

@assert m()  == 1
@assert m(1) == 2

end # module
