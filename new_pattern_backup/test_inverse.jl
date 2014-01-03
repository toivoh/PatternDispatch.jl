module TestInverse
using Inverses

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

nodeseq = Inverses.inverses[MyType]
print(nodeseq.nodes)
print(nodeseq.bindings)

end # module
