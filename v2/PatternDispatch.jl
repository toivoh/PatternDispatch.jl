load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug

include(find_in_path("PatternDispatch/src/Immutable.jl"))
include(find_in_path("PatternDispatch/v2/Patterns.jl"))
include(find_in_path("PatternDispatch/v2/Recode.jl"))
using Recode


end # module
