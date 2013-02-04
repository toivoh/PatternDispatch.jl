module PatternDispatch
export @pattern, show_dispatch

include(Pkg.dir()*"/PatternDispatch/src/Meta.jl")

include(Pkg.dir()*"/PatternDispatch/src/Immutable.jl")
include(Pkg.dir()*"/PatternDispatch/src/Patterns.jl")
include(Pkg.dir()*"/PatternDispatch/src/Nodes.jl")
include(Pkg.dir()*"/PatternDispatch/src/Recode.jl")

include(Pkg.dir()*"/PatternDispatch/src/PartialOrder.jl")
include(Pkg.dir()*"/PatternDispatch/src/Dispatch.jl")
include(Pkg.dir()*"/PatternDispatch/src/Encode.jl")

include(Pkg.dir()*"/PatternDispatch/src/Methods.jl")
using Methods
import Methods.method_tables

end # module
