module TestDAG

using PatternDispatch: Ops, DAGs, PatternDAGs
using PatternDispatch.Common: emit!, calc!

primary_eq(x, y) = primary_rep(x) === primary_rep(y)


g = DAG()
args = calc!(g, Arg())
x = calc!(g, TupleRef(1), args)
y = calc!(g, TupleRef(2), args)
@assert calc!(g, TupleRef(1), args) === x
@assert !primary_eq(x, y)

emit!(g, EgalGuard(), x, y)
@assert primary_eq(x, y)


g = DAG()
t = calc!(g, Arg())
n = 5
args = [calc!(g, TupleRef(k)) for k=1:n]
for k=1:n, l=1:n
    @assert primary_eq(args[k], args[l]) == (k == l)
end

emit!(g, EgalGuard(), args[1], args[2])
emit!(g, EgalGuard(), args[3], args[4])
for k=1:n, l=1:n
    @assert primary_eq(args[k], args[l]) == (((k-1)&~1)==((l-1)&~1))
end

emit!(g, EgalGuard(), args[1], args[4])
for k=1:n, l=1:n
    @assert primary_eq(args[k], args[l]) == ((k<=4)==(l<=4))
end


g = DAG()
t = calc!(g, Arg())
args = [calc!(g, TupleRef(k)) for k=1:3]
d12 = calc!(g, Call(-), args[1], args[2])
d13 = calc!(g, Call(-), args[1], args[3])
d21 = calc!(g, Call(-), args[2], args[1])
@assert !primary_eq(d12, d13)
@assert !primary_eq(d12, d21)
@assert !primary_eq(d13, d21)
emit!(g, EgalGuard(), args[2], args[3])
@assert primary_eq(d12, d13)
@assert !primary_eq(d12, d21)
emit!(g, EgalGuard(), args[1], args[2])
@assert primary_eq(d12, d13)
@assert primary_eq(d12, d21)
@assert !primary_eq(d12, args[1])


g = DAG()
t = calc!(g, Arg())
args = [calc!(g, TupleRef(k)) for k=1:4]
s = [calc!(g, Call(sin), args[k]) for k=1:4]
emit!(g, EgalGuard(), s[1], s[2])
emit!(g, EgalGuard(), s[3], s[4])
emit!(g, EgalGuard(), args[1], args[3])
@assert primary_eq(s[1], s[4])


g = DAG()
t = calc!(g, Arg())
emit!(g, TypeGuard(Matrix), t)
emit!(g, TypeGuard(Array{Int}), t)
@assert TGof(g, t) == Matrix{Int}


g = DAG()
t = calc!(g, Arg())
x, y = calc!(g, TupleRef(1), t), calc!(g, TupleRef(2), t)
emit!(g, TypeGuard(Matrix),     x)
emit!(g, TypeGuard(Array{Int}), y)
@assert TGof(g, x) == Matrix
@assert TGof(g, y) == Array{Int}
emit!(g, EgalGuard(), x, y)
@assert TGof(g, x) == Matrix{Int}


g = Graph()
t = calc!(g, Arg())
@assert !nevermatches(g)
emit!(g, TypeGuard(None), t)
@assert nevermatches(g)

g = Graph()
t = calc!(g, Arg())
emit!(g, TypeGuard(Real), t)
@assert !nevermatches(g)
emit!(g, TypeGuard(String), t)
@assert nevermatches(g)

g = Graph()
s1 = calc!(g, Source(1))
s2 = calc!(g, Source(2))
@assert !nevermatches(g)
emit!(g, EgalGuard(), s1, s2)
@assert nevermatches(g)

g = Graph()
s = calc!(g, Source(1))
@assert TGof(g, s) == Int

g = Graph()
s = calc!(g, Source(1))
@assert !nevermatches(g)
emit!(g, TypeGuard(String), s)
@assert nevermatches(g)

end
