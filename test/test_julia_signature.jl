module TestJuliaSignature
using PatternDispatch.Nodes, PatternDispatch.Recode

@show julia_signature_of(@qpat (x,))
@show julia_signature_of(@qpat (x::Int,))
@show julia_signature_of(@qpat (x,y))
@show julia_signature_of(@qpat (x,y::Int))
@show julia_signature_of(@qpat (x::Number,y::AbstractString))
@show julia_signature_of(@qpat (x::Int,(y::Int,z::Real)))

end
