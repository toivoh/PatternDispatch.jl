include(find_in_path("PatternDispatch.jl"))

module TryCooperative
import PatternDispatch.Nodes.julia_signature_of
using PatternDispatch, PatternDispatch.PartialOrder, PatternDispatch.Dispatch
using PatternDispatch.DecisionTree, PatternDispatch.Patterns

@pattern f(1)      = 42
@pattern f(x::Int) = x
@pattern f(x)      = 0

mt = PatternDispatch.method_tables[f]

nodes = subDAGof(mt.top)
methods = methodsof(mt)
actual_methods = filter(m->(m != nomethod), methods)
hullTs = Set{Tuple}(Tuple[m.hullT for m in actual_methods]...)

ltT(S,T) = !(S==T) && (S<:T)
function dominated_wrt(node::MethodNode, cut::Intension)
    any([intentof(child) & cut == intentof(node) & cut for child in node.gt])
end

for hullT in hullTs
    top = copyDAG(mt.top)

    # filter out too specific methods
    keep = Set{Method}(filter(m->!ltT(m.hullT, hullT), methods)...)
    @assert !isempty(keep)
    raw_filter!(top, keep)

    # filter out non-questions
    hull = intension(hullT)
    top = simplify!(top, hull)

    @show hullT
    @show tuple([node.value.sig for node in subDAGof(top)]...)
    @show top.value.sig
    println()
end




end # module
