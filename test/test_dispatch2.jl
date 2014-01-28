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
MyType(x) = MyType(x, x)

#@pattern function (@inverse MyType(x, y))(ex::MyType)
@pattern function (@inverse MyType(x, y))(ex)
    ex::MyType
    x = ex.x
    y = ex.y
end
@pattern function (@inverse MyType(x))(ex)
    ex::MyType
    x = ex.x
    y = ex.y
    x ~ y
end

@pattern g(MyType(x::Int, y)) = (1,x,y)
@pattern g(MyType(x::Int, 1)) = (2,x)

@assert g(MyType(4, 1))   === (2,4)
@assert g(MyType(4, 2))   === (1,4,2)
@assert g(MyType(4, 1.0)) === (1,4,1.0)

@pattern g2(MyType(x))   = (1,x)
@pattern g2(MyType(x,y)) = (2,x,y)

@assert g2(MyType(5,5)) === (1,5)
@assert g2(MyType(5,6)) === (2,5,6)


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


type MyTuple
    t::Tuple
    MyTuple(args...) = new(tuple(args...))
end

@patterns begin
    function (@inverse MyTuple(x))(ex)
        ex::MyTuple
        t = ex.t::(Any,)
        x = t[1]
    end
    function (@inverse MyTuple(x,y))(ex)
        ex::MyTuple
        t = ex.t::(Any,Any)
        x = t[1]
        y = t[2]
    end

    j(MyTuple(x))   = x
    j(MyTuple(x,y)) = (x, y)
end

@assert j(MyTuple(5))   === 5
@assert j(MyTuple(5,6)) === (5,6)


@patterns begin
    function (@inverse Expr(head))(ex)
        ex::Expr
        length(ex.args)~0
        head = ex.head
    end
    function (@inverse Expr(head, arg1))(ex)
        ex::Expr
        length(ex.args)~1
        head = ex.head
        arg1 = ex.args[1]
    end
    function (@inverse Expr(head, arg1, arg2))(ex)
        ex::Expr
        length(ex.args)~2
        head = ex.head
        arg1 = ex.args[1]
        arg2 = ex.args[2]
    end
    function (@inverse Expr(head, arg1, arg2, arg3))(ex)
        ex::Expr
        length(ex.args)~3
        head = ex.head
        arg1 = ex.args[1]
        arg2 = ex.args[2]
        arg3 = ex.args[3]
    end

    simplify(ex) = ex
    simplify(Expr(:call, op, ex))            = Expr(:call,op,simplify(ex))
    simplify(Expr(:call, op, ex1, ex2))      = Expr(:call,op,simplify(ex1),simplify(ex2))
    simplify(Expr(:call, :+, ex::Symbol, ex))            = Expr(:call,:*,2,simplify(ex))
    simplify(Expr(:call, :+, ex::Symbol, Expr(:call,:*,f,ex))) = Expr(:call,:*,1+f,simplify(ex))
    simplify(Expr(:call, :+, Expr(:call,:*,f,ex), ex::Symbol)) = Expr(:call,:*,f+1,simplify(ex))
    function simplify(Expr(:call, :+, Expr(:call,:*,f1,ex::Symbol), Expr(:call,:*,f2,ex::Symbol)))
        Expr(:call,:*,f1+f2,simplify(ex))
    end
end

@show simplify(:((x+x)/(2y+3y)))
@show simplify(:(x+x))
#show_dispatch(simplify)

@patterns begin
    unexpr(ex) = ex
    unexpr(Expr(head)) = (head,)
    unexpr(Expr(head, arg1)) = (head, arg1)
    unexpr(Expr(head, arg1, arg2)) = (head, arg1, arg2)
end

@show unexpr(:(x+x))
@show unexpr(:(-x))

end # module
