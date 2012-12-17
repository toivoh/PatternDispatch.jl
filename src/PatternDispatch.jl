load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @pattern, @qpat, simplify, unbind

include(find_in_path("PatternDispatch/src/Immutable.jl"))
include(find_in_path("PatternDispatch/src/Graph.jl"))
include(find_in_path("PatternDispatch/src/Recode.jl"))
include(find_in_path("PatternDispatch/src/CodeMatch.jl"))
include(find_in_path("PatternDispatch/src/Macros.jl"))
using Graph, Recode, CodeMatch
using Macros


macro qpat(ex)
    recode(ex)
end

end # module
