module PatternDispatch
export @pattern, show_dispatch

include(julia_pkgdir()*"/PatternDispatch/src/Meta.jl")
include(julia_pkgdir()*"/PatternDispatch/src/PartialOrder.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Immutable.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Patterns.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Nodes.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Recode.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Encode.jl")
include(julia_pkgdir()*"/PatternDispatch/src/DecisionTree.jl")
include(julia_pkgdir()*"/PatternDispatch/src/Dispatch.jl")
using Meta, Patterns, Nodes, Recode, Dispatch
import Dispatch.show_dispatch


const method_tables = Dict{Function, MethodTable}()

function show_dispatch(f::Function, args...)
    if !has(method_tables, f);  error("not a pattern function: $f")  end
    show_dispatch(method_tables[f], args...)
end

macro pattern(ex)
    code_pattern(ex)
end
function code_pattern(ex)
    sig, body = try
        split_fdef(ex)
    catch e
        error("@pattern: not a function definition ($e)")
    end
    @expect is_expr(sig, :call)
    fname, args = sig.args[1], sig.args[2:end]
    if is_expr(fname, :curly)
        error("@pattern: type parameters are not implemented")
    end
    psig = :($(args...),)
    p_ex, bodyargs = recode(psig)
    
    f = esc(fname::Symbol)
    quote       
        local p = $p_ex
        local bindings = Node[p.bindings[name] for name in $(quot(bodyargs))]
        local bodyfun = $(esc(:(($(bodyargs...),)->$body)))
        local method = Method(p, bindings, bodyfun, $(quot(body)))

        local wasbound = try
            f = $f
            true
        catch e
            false
        end

        local mt
        if !wasbound
            mt = MethodTable($(quot(fname)))
            local const f = mt.f
            const $f = (args...)->f(args...)
            method_tables[$f] = mt
            add(mt, method)
        else
            if !has(method_tables, $f)
                error($("$fname is not a pattern function"))
            end
            add(method_tables[$f], method)
        end
    end
end

end # module
