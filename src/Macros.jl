
module Macros
using Graph, Recode, CodeMatch, Toivo
export @pattern


# ==== MethodTable ============================================================

type Method
    sig::Pattern
    f::Function
end

type MethodTable
    name::Symbol
    methods::Vector{Method}
    MethodTable(name::Symbol) = new(name, Method[])
end

function add(mt::MethodTable, m::Method)
    # insert the pattern in ascending topological order, as late as possible
    i = length(mt.methods)+1
    for (k, mk) in enumerate(mt.methods)
        if m.sig <= mk.sig
            if m.sig >= mk.sig
                # equal signature ==> replace
                mt.methods[k] = m
                return
            else
                i = k
                break
            end
        end
    end
    insert(mt.methods, i, m)
end

function dispatch(mt::MethodTable, args::Tuple)
    for m in mt.methods
        matched, result = m.f(args)
        if matched; return result; end
    end
    error("No matching method found for pattern function $(mt.name)")
end


function create_method(p::Pattern, body)
    code = code_match(p)
    f = @eval $argsym->begin
        $(code)
        (true, $body)
    end
    Method(p, f)
end

# ==== @pattern ===============================================================

const method_tables = Dict{Function, MethodTable}()

macro pattern(ex)
    code_pattern(ex)
end

function code_pattern(ex)
    sig, body = split_fdef(ex)
    @expect is_expr(sig, :call)
    fname, args = sig.args[1], sig.args[2:end]
    psig = :($(args...),)
    p_ex = recode(psig)
    
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
            const $f = (args...)->dispatch(mt, args)
            method_tables[$f] = mt
        else
            if !has(method_tables, $f)
                error($("$fname is not a pattern function"))
            end
            mt = method_tables[$f]
        end

        method = create_method($p_ex, $(quot(body)))
        add(mt, method)
    end
end

end # module
