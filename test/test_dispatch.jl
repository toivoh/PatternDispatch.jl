include(find_in_path("PatternDispatch.jl"))

module TestDispatch
using PatternDispatch

@pattern f(3)      = 3
@pattern f(x::Int) = x^2
@pattern f(x~::String) = 5

@pattern g(x)     = x
@pattern g((x,y)) = x*y

@pattern h((x,y),(z,w)) = [x,y,z,w]
@pattern h(x,(y,z)) = [x,y,z]
@pattern h((x,y),z) = [x,y,z]

@pattern l(::Number) = 2
@pattern l(::Any)    = 1

@pattern m()        = 1
@pattern m(x)       = 2
#@pattern m(args...) = 3

end # module
