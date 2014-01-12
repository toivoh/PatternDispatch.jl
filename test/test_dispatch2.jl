module TestDispatch2

using PatternDispatch

@pattern f(x::Int, y) = (1,x,y)
@pattern f(x::Int, 1) = (2,x)

@assert f(4, 1)   === (2,4)
@assert f(4, 2)   === (1,4,2)
@assert f(4, 1.0) === (1,4,1.0)


type MyType
    x
    y
end

#@pattern function (@inverse MyType(x, y))(ex::MyType)
@pattern function (@inverse MyType(x, y))(ex)
    ex::MyType
    x = ex.x
    y = ex.y
end

@pattern g(MyType(x::Int, y)) = (1,x,y)
@pattern g(MyType(x::Int, 1)) = (2,x)

@assert g(MyType(4, 1))   === (2,4)
@assert g(MyType(4, 2))   === (1,4,2)
@assert g(MyType(4, 1.0)) === (1,4,1.0)


doubleint(x::Int) = 2x

@patterns begin
    function (@inverse doubleint(x))(y)
        y::Int
        @guard iseven(y)
        x = y >> 1
    end

    h(doubleint(x)) = x
    h(x) = x
end

@assert [h(x) for x=0:5] == [0, 1, 1, 3, 2, 5]


end # module
