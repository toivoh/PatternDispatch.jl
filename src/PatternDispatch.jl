load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @pattern, show_dispatch

include(find_in_path("PatternDispatch/src/PartialOrder.jl"))
include(find_in_path("PatternDispatch/src/Immutable.jl"))
include(find_in_path("PatternDispatch/src/Patterns.jl"))
include(find_in_path("PatternDispatch/src/Nodes.jl"))
include(find_in_path("PatternDispatch/src/Recode.jl"))
include(find_in_path("PatternDispatch/src/Encode.jl"))
include(find_in_path("PatternDispatch/src/DecisionTree.jl"))
include(find_in_path("PatternDispatch/src/Dispatch.jl"))
using Patterns, Nodes, Recode, Dispatch
import Dispatch.show_dispatch


const method_tables = Dict{Function, MethodTable}()

function show_dispatch(f::Function)
    if !has(method_tables, f);  error("not a pattern function: $f")  end
    show_dispatch(method_tables[f])
end

macro pattern(ex)
    code_pattern(ex)
end
function code_pattern(ex)
    sig, body = split_fdef(ex)
    @expect is_expr(sig, :call)
    fname, args = sig.args[1], sig.args[2:end]
    psig = :($(args...),)
    p_ex, bodyargs = recode(psig)
    
    f = esc(fname)
    quote       
        wasbound = try
            f = $f
            true
        catch e
            false
        end

        if !wasbound
            mt = MethodTable($(quot(fname)))
            const f = mt.f
            const $f = (args...)->f(args...)
            method_tables[$f] = mt
        else
            if !has(method_tables, $f)
                error($("$fname is not a pattern function"))
            end
            mt = method_tables[$f]
        end

        p = $p_ex
        bindings = Node[p.bindings[name] for name in $(quot(bodyargs))]
        method = Method(p, bindings, $(esc(:(($(bodyargs...),)->$body))))
        add(mt, method)
    end
end

end # module
