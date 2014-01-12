module PatternDispatch
export @pattern, @patterns, show_dispatch

include("Common.jl")
include("PartialOrder.jl")
include("Ops.jl")
include("Nodes.jl")
include("Graphs.jl")
include("PatternGraphs.jl")
include("Recode.jl")
include("Patterns.jl")
include("Encode.jl")
include("Inverses.jl")
include("Methods.jl")
include("Macros.jl")

using .Macros: @pattern, @patterns, show_dispatch

end # module
