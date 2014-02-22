module TestQPat

using PatternDispatch.Patterns


@show @qpat( x )
println()
@show @qpat( x~y )
println()
@show @qpat( x::Int )
println()
@show @qpat( (x,y) )
println()
@show @qpat( t~(x,y) )
println()

@eval @show @qpat( $(Expr(:(::), :Int)) )
println()
@show @qpat( (x::Int,y) )
println()
@show @qpat( x~(y~(z,v),w) )
println()
@show @qpat( x::Int::Real )
println()
@show @qpat( x::Int::Float64 )
println()
@show @qpat( x::Matrix::Array{Int} )
println()
@show @qpat((x::Int,x~y))
println()
@show @qpat((x::Int, y::Real, x~y))
println()
@show @qpat(1~1)
println()
@show @qpat(1~2)
println()
@show @qpat(1::Int)
println()
@show @qpat(1.0::Int)
println()
@show @qpat($(1,2)::(Int, Int, Int, Int...))
println()
@show @qpat($(1,2)::Tuple)
println()
@show @qpat(($(1,2)~(x,y),x,y))
println()

f(x,y) = x+y
@show @qpat(f(x,y::Int))
println()

@show @qpat(v~[x,y::Int,3])
println()
@show @qpat([x]::String)
println()

end
