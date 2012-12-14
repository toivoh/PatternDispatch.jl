include(find_in_path("PatternDispatch.jl"))

module TestImmutable
using PatternDispatch

@immutable type T
    x::Int
end
@immutable type S
    x    
end
@immutable type XY
    x
    y
end


@assert !(T(7)::T === T(42)::T)
@assert T(42)::T === T(42)::T

@assert !(S(7)::S === S(42)::S)
@assert S(42)::S === S(42)::S
@assert S(42)::S === S(42.0)::S # current semantics, subject to change...

@assert !(S(42)::S === T(42)::T)

@assert !(XY(1,2)::XY === XY(3,4)::XY)
@assert !(XY(1,2)::XY === XY(1,4)::XY)
@assert !(XY(1,2)::XY === XY(3,2)::XY)
@assert (XY(1,2)::XY === XY(1,2)::XY)
@assert (XY(3,4)::XY === XY(3,4)::XY)

end