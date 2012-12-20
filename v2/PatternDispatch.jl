load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @qpat

include(find_in_path("PatternDispatch/src/Immutable.jl"))
include(find_in_path("PatternDispatch/v2/Patterns.jl"))
include(find_in_path("PatternDispatch/v2/Recode.jl"))
using Patterns, Recode

macro qpat(ex)
    recode(ex)
end

end # module
