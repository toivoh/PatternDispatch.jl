module PatternDispatch
export @pattern, show_dispatch

include("Meta.jl")

include("Intern.jl")
include("Patterns.jl")
include("Nodes.jl")
include("Recode.jl")

include("PartialOrder.jl")
include("Dispatch.jl")
include("Encode.jl")

include("Methods.jl")
using .Methods
import .Methods.method_tables

end # module
