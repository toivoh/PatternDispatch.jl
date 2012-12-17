
module Macros
using Graph, Recode, CodeMatch, Toivo
export @pattern


# ==== MethodTable ============================================================

type MethodTable
    name::Symbol
    methods::Vector{Function}
    MethodTable(name::Symbol) = new(name, Function[])
end

add(mt::MethodTable, m::Function) = (push(mt.methods, m); nothing)

function dispatch(mt::MethodTable, args::Tuple)
    for m in mt.methods
        matched, result = m(args)
        if matched; return result; end
    end
    error("No matching method found for pattern function $(mt.name)")
end


function create_method(p::Pattern, body)
    code = code_match(p)
    @eval $argsym->begin
        $(code)
        (true, $body)
    end
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
            println($("$fname was unbound"))
        else
            if !has(method_tables, $f)
                error($("$fname is not a pattern function"))
            end
            mt = method_tables[$f]
            println($("$fname was a pattern function"))
        end

        method = create_method($p_ex, $(quot(body)))
        add(mt, method)
    end
end

end # module
