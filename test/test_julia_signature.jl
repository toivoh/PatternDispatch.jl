require("PatternDispatch.jl")

module TestJuliaSignature
using PatternDispatch.Patterns, PatternDispatch.Recode

@show julia_signature_of(@qpat (x,))
@show julia_signature_of(@qpat (x::Int,))
@show julia_signature_of(@qpat (x,y))
@show julia_signature_of(@qpat (x,y::Int))
@show julia_signature_of(@qpat (x::Number,y::String))
@show julia_signature_of(@qpat (x::Int,(y::Int,z::Real)))

end
