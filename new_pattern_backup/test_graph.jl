include("reload.jl")


module TestGraph

using Graphs

immutable Source <: Op; value;      end
immutable Op <: Op;     op::Symbol; end


g = Graph()
x = addnode!(g, Source(:x))
y = addnode!(g, Source(:y))
z = addnode!(g, Source(:z))

n1 = addnode!(g, Op(:+), x, y)
n2 = addnode!(g, Op(:+), x, y)
n3 = addnode!(g, Op(:+), x, z)

@assert n1 === n2
@assert !(n1 === n3)

@assert (1,n1) in refsof(x)
@assert (2,n1) in refsof(y)
@assert (1,n3) in refsof(x)
@assert (2,n3) in refsof(z)

@assert length(refsof(x)) == 2
@assert length(refsof(y)) == 1
@assert length(refsof(z)) == 1

@assert length(nodesof(g)) == 5

setarg!(g, n3, y, 2)

@assert live_rep(n3) === n1

@assert (1,n1) in refsof(x)
@assert (2,n1) in refsof(y)

@assert length(refsof(x)) == 1
@assert length(refsof(y)) == 1
@assert length(refsof(z)) == 0

@assert length(nodesof(g)) == 4

end # module
