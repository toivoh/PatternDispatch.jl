module TestAmbWarning
using Macros

@patterns begin
    f(x::Int, y) = 1
    f(x, y::Int) = 2
end

@patterns begin
    g(1, y) = 1
    g(x, 2) = 2
end

end