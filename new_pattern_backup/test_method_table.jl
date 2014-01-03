module TestMethodTable

using Methods
using Macros


mt = MethodTable(:f)

m1 = (@qmethod f(x::Int, y) = (1,x,y))
m2 = (@qmethod f(x::Int, 1) = (2,x))

addmethod!(mt, m1)
addmethod!(mt, m2)

@show encode(mt)

eval(encode(mt))

@assert f(4, 1)   === (2,4)
@assert f(4, 2)   === (1,4,2)
@assert f(4, 1.0) === (1,4,1.0)


end # module
