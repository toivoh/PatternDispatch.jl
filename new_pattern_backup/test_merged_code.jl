module TestMerged

using Patterns
using Encode, Encode.Return, Encode.Call
using Common: emit!, calc!, branch!, finish!, reemit!

f1(x,y) = (1,x,y)
f2(x) = (2,x)

p1 = (@qpat (x::Int, y))
p2 = (@qpat (x::Int, 1))

# fix order of args to correspond to f1 and f2
p1.argkeys = Symbol[:x, :y]
p2.argkeys = Symbol[:x]


seq = CodeSeq()


c1 = CachedCode(LowerTo(seq))
map1 = reemit!(c1, p1.g)
args1 = [map1[p1.bindings[key]] for key in p1.argkeys]

c2 = branch!(c1)
map2 = reemit!(c2, p2.g)
args2 = [map2[p2.bindings[key]] for key in p2.argkeys]
emit!(c2, Return(), calc!(c2, Call(f2), args2...))
finish!(c2)

emit!(c1, Return(), calc!(c1, Call(f1), args1...))
finish!(c1)


code = {}
m = MatchCode(code)
reemit!(m, seq)
finish!(m)

ex = blockexpr(code)

show(ex)

end # module
