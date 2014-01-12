module TestShowDispatch

using PatternDispatch

@pattern f(x::Int, y) = (1,x,y)
@pattern f(x::Int, 1) = (2,x)

show_dispatch(f)

end # module
