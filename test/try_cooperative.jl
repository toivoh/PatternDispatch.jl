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
    hull = intension(hullT)
    # filter out too specific methods
    ns = [filter(node->!ltT(node.value.hullT, hullT), nodes)...]
    # filter out non-questions
    ns = [filter(node->!dominated_wrt(node, hull), ns)...]

    kept = prune(mt.top, Set{MethodNode}(ns...))
    for node in [kept...]
        del_each(kept, node.gt)
    end
    @assert length(kept) == 1
    top = [kept...][1]

    @show hullT
    @show [node.value.sig for node in ns]

    @show top.value.sig
    println()

end




end # module
