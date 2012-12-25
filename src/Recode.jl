
# Recode: function signature -> Pattern creating AST
module Recode
using Meta, Patterns, Nodes
export recode, @qpat, @ipat

macro qpat(ex)
    recode(ex)[1]
end
macro ipat(ex)
    c = Context()
    recode(c, quot(argnode), ex)
    quote
        $(c.code...)
        intension($(c.guards...))
    end
end

type Context
    code::Vector
    guards::Vector
    bindings::Vector
    Context() = new({}, {}, {})
end

const typed_dict = symbol("typed-dict")
function recode(ex)
    c = Context()
    recode(c, quot(argnode), ex)
    p_ex = quote
        $(c.code...)
        Pattern(intension($(c.guards...)), 
                $(expr(typed_dict, :(Symbol=>Node), c.bindings...)))
    end
    p_ex, Symbol[b.args[1].args[1] for b in c.bindings]
end

recode(c::Context, arg, ex) = push(c.guards, :(egalpred($arg,$(quot(ex)))))
recode(c::Context, arg, ex::Symbol) = push(c.bindings, :($(quot(ex))=>$arg))
function recode(c::Context, arg, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head === :(::)
        @assert 1 <= nargs <= 2
        if nargs == 1
            push(c.guards, :( typepred($arg, $(esc(args[1]))) ))
        else
            push(c.guards, :( typepred($arg, $(esc(args[2]))) ))
            recode(c, arg, args[1])
        end
    elseif head === :tuple
        push(c.guards, :( typepred($arg, $(quot(NTuple{nargs,Any}))) ))
        for (k, p) in enumerate(args)
            node = gensym("e$k")
            push(c.code, :( $node = tupref($arg, $k) ))
            recode(c, node, p)
        end
    elseif head === :call && args[1] == :~
        for p in args[2:end]; recode(c, arg, p); end
    else
        error("recode: unimplemented: ex = $ex")
    end
end

end # module
