
# Recode: function signature -> Pattern creating AST
module Recode
using ..Meta, ..Patterns, ..Nodes
export recode, @qpat, @ipat
export refnode, egalpred, typepred, lengthnode

macro qpat(ex)
    recode(ex)[1]
end
macro ipat(ex)
    c = Context()
    recode(c, quot(argnode), ex)
    quote
        $(c.code...)
        intension($(c.preds...))
    end
end

type Context
    code::Vector
    preds::Vector
    bindings::Vector
    Context() = new({}, {}, {})
end

const typed_dict = symbol("typed-dict")
function recode(ex)
    c = Context()
    recode(c, quot(argnode), ex)
    p_ex = quote
        $(c.code...)
        Pattern(intension($(c.preds...)), 
                $(expr(typed_dict, :(Symbol=>Node), c.bindings...)))
    end
    syms = Symbol[b.args[1].args[1] for b in c.bindings] 
    if length(syms) != length(Set{Symbol}(syms...))
        error("@pattern: Non-tree patterns not yet implemented. Use unique argument names.")
    end
    p_ex, syms
end

recode(c::Context, arg, ex) = push!(c.preds, :(egalpred($arg,$(quot(ex)))))
recode(c::Context, arg, ex::Symbol) = push!(c.bindings, :($(quot(ex))=>$arg))
function recode(c::Context, arg, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head === :(::)
        @assert 1 <= nargs <= 2
        if nargs == 1
            push!(c.preds, :( typepred($arg, $(esc(args[1]))) ))
        else
            push!(c.preds, :( typepred($arg, $(esc(args[2]))) ))
            recode(c, arg, args[1])
        end
    elseif head === :tuple || head === :vcat
        argtype = (head === :tuple) ? Tuple : Vector
        push!(c.preds, :( typepred($arg, $(quot(argtype))) ))
        push!(c.preds, :( egalpred(lengthnode($arg), $(quot(nargs))) ))
        for (k, p) in enumerate(args)
            node = gensym("e$k")
            push!(c.code, :( $node = refnode($arg, $k) ))
            recode(c, node, p)
        end
    elseif head === :cell1d
        error("@pattern: use [] for array patterns")
    elseif head === :call && args[1] == :~
        for p in args[2:end]; recode(c, arg, p); end
    elseif head === :$ && nargs == 1
        push!(c.preds, :(egalpred($arg, $(esc(args[1])))))
    elseif head === :... && nargs == 1
        error("@pattern: varargs are not yet implemented")
    else
        error("recode: unimplemented: ex = $ex")
    end
end

end # module
