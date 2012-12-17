
# CodeMatch: Pattern -> matching code
module CodeMatch
using Graph, Toivo
export code_match

type Ctx
    code::Vector
    values::Dict{Value,Symbol}
    bound::Set{Symbol}
    Ctx() = new({}, Dict{Value,Symbol}(), Set{Symbol}())
end

emit(c::Ctx, ex) = (push(c.code, ex); nothing)
emit_guard(c::Ctx, ex) = emit(c, :( if !$ex; return (false,nothing); end ))

function code_match(p::Pattern)
    c = Ctx()
    for g in p.guards
        code_match(c, g)
    end
    quote; $(c.code...); end
end

function code_match(c::Ctx, v::Value)
    if has(c.values, v)
        c.values[v]
    else
        val = gensym("v")
        emit(c, :( $val = $(code_val(c, v)) ))
        c.values[v] = val
    end
end

code_val(c::Ctx, v::Arg)      = argsym
code_val(c::Ctx, v::TupleRef) = :( $(code_match(c,v.arg))[$(v.index)] )

function code_match(c::Ctx, g::Bind)
    if has(c.bound, g.name)
        emit_guard(c, :( is($(code_match(c,g.arg)), $(g.name)) ))
    else
        emit(c, :( $(g.name) = $(code_match(c,g.arg)) ))
    end
end
code_match(c::Ctx, g::Guard) = emit_guard(c, code_pred(c, g))

code_pred(c::Ctx,g::Egal) = :(is( $(code_match(c, g.arg)), $(quot(g.value))))
code_pred(c::Ctx,g::Isa)  = :(isa($(code_match(c, g.arg)), $(quot(g.typ  ))))

end # module
