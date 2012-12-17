
# CodeMatch: Pattern -> matching code
module CodeMatch
using Graph, Toivo
export code_match

type Ctx
    code::Vector
    results::Dict{Node,Any}
    bound::Set{Symbol}
    Ctx() = new({}, Dict{Node,Any}(), Set{Symbol}())
end

emit(c::Ctx, ex) = (push(c.code, ex); nothing)
emit_guard(c::Ctx, ex) = emit(c, :( if !$ex; return (false,nothing); end ))

function code_match(p::Pattern)
    c = Ctx()
    for g in values(p.guards); evaluate(c, g); end
    for b in p.bindings;       evaluate(c, b); end
    quote; $(c.code...); end
end

function evaluate(c::Ctx, node::Node)
    if has(c.results, node)
        c.results[node]
    else
        ex = code_match(c, node)
        if (isa(ex, Symbol) || ex === nothing)
            c.results[node] = ex
        else
            val = gensym("v")
            emit(c, :( $val = $ex ))
            c.results[node] = val            
        end
    end
end

code_match(c::Ctx, v::Arg)      = argsym
code_match(c::Ctx, v::TupleRef) = :( $(evaluate(c,v.arg))[$(v.index)] )

function code_match(c::Ctx, g::Bind)
    if has(c.bound, g.name)
        emit_guard(c, :( is($(evaluate(c,g.arg)), $(g.name)) ))
    else
        emit(c, :( $(g.name) = $(evaluate(c,g.arg)) ))
    end
end
code_match(c::Ctx, g::Guard) = emit_guard(c, code_pred(c, g))

code_pred(c::Ctx,g::Egal) = :(is( $(evaluate(c, g.arg)), $(quot(g.value))))
code_pred(c::Ctx,g::Isa)  = :(isa($(evaluate(c, g.arg)), $(quot(g.typ  ))))

end # module
