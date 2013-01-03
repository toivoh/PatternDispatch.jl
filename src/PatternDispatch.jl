module PatternDispatch
export @pattern, show_dispatch

include(julia_pkgdir()*"/PatternDispatch/src/Meta.jl")

include(julia_pkgdir()*"/PatternDispatch/src/Immutable.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Patterns.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Nodes.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Recode.jl")

include(julia_pkgdir()*"/PatternDispatch/src/PartialOrder.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Dispatch.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Encode.jl")

include(julia_pkgdir()*"/PatternDispatch/src/Methods.jl")
using Methods
import Methods.method_tables

end # module
