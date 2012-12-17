load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @pattern, @qpat, @spat, simplify, unbind

include(find_in_path("PatternDispatch/src/Immutable.jl"))
include(find_in_path("PatternDispatch/src/Graph.jl"))
include(find_in_path("PatternDispatch/src/Recode.jl"))
include(find_in_path("PatternDispatch/src/CodeMatch.jl"))
include(find_in_path("PatternDispatch/src/Ops.jl"))
include(find_in_path("PatternDispatch/src/Macros.jl"))
using Graph, Recode, CodeMatch, Ops
using Macros


macro qpat(ex)
    recode(ex)
end
macro spat(ex)
    quote
        simplify($(recode(ex)))
    end
end

end # module
