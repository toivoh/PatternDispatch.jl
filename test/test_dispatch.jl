module TestDispatch

using PatternDispatch


@patterns begin
    f2(x::Int) = x^2
    f2(3)      = 3
    f2(x~::String) = 5
end

@assert [f2(x) for x=1:4] == [1,4,3,16]
@assert f2("foo") == 5


@patterns begin
    g2((x,y)) = x*y
    g2(x)     = x
end

@assert g2(11) == 11
@assert g2((2,6)) == 12
@assert g2([2,6]) == [2,6]


@patterns begin
    g3([x,y]) = x*y
    g3(x)     = x
end

@assert g3(11) == 11
@assert g3([2,6]) == 12
@assert g3((2,6)) == (2,6)


@patterns begin
    h(x,(y,z))     = [x,y,z]
    h((x,y),(z,w)) = [x,y,z,w]
    h((x,y),z)     = [x,y,z]
end

@assert h((1,2),(3,4)) == [1,2,3,4]
@assert h(1,(2,3))     == [1,2,3]
@assert h((1,2),3)     == [1,2,3]
@assert h((1,2),[3,4]) == [1,2,[3,4]]


@patterns begin
    h2(x,[y,z])     = [x,y,z]
    h2([x,y],[z,w]) = [x,y,z,w]
    h2([x,y],z)     = [x,y,z]
end

@assert h2([1,2],[3,4]) == [1,2,3,4]
@assert h2(1,[2,3])     == [1,2,3]
@assert h2([1,2],3)     == [1,2,3]
@assert h2([1,2],(3,4)) == [1,2,(3,4)]


@patterns begin
    l(::Any)    = 1
    l(::Number) = 2
end

@assert l(5) == l(5.0) == 2
@assert l(:x) == l("x") == l([1,2]) == 1


@patterns begin
    m()        = 1
    m(x)       = 2
#    m(args...) = 3
end

@assert m()  == 1
@assert m(1) == 2


end # module
