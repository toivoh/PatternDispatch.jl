
# Recode: function signature -> Pattern creating AST
module Recode
using Graph, Toivo
export recode

type Context
    code::Vector
    guards::Vector
    Context() = new({}, {})
end

function recode(ex)
    r = Context()
    recode(r, quot(Arg()), ex)
    quote
        $(r.code...)
        Pattern(Guard[$(r.guards...)])
    end
end

recode(c::Context, arg, ex)         = push(c.guards, :(Egal($arg,$(quot(ex)))))
recode(c::Context, arg, ex::Symbol) = push(c.guards, :(Bind($arg,$(quot(ex)))))
function recode(c::Context, arg, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head === :(::)
        @assert 1 <= nargs <= 2
        if nargs == 1
            push(c.guards, :( Isa($arg, $(esc(args[1]))) ))
        else
            push(c.guards, :( Isa($arg, $(esc(args[2]))) ))
            recode(c, arg, args[1])
        end
    elseif head === :tuple
        push(c.guards, :( Isa($arg, $(quot(NTuple{nargs,Any}))) ))
        for (k, p) in enumerate(args)
            node = gensym("e$k")
            push(c.code, :( $node = TupleRef($arg, $k) ))
            recode(c, node, p)
        end
    elseif head === :call && args[1] == :~
        for p in args[2:end]; recode(c, arg, p); end
    else
        error("recode: unimplemented: ex = $ex")
    end
end

end # module
