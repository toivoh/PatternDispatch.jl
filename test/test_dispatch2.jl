include(find_in_path("PatternDispatch.jl"))

module TestDispatch2
import PatternDispatch, PatternDispatch.Dispatch
using PatternDispatch, PatternDispatch.Patterns, PatternDispatch.Dispatch

@pattern f(x::Int) = 1
@pattern f(1) = 2
@pattern f(2.5) = 11

mt = PatternDispatch.method_tables[f]
Dispatch.create_dispatch2(mt)

@show f(4)
@show f(1)
@show f(2.5)

end # module
