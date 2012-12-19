
# CodeMatch: Pattern -> matching code
module CodeMatch
using Graph, Toivo
export code_match

type Ctx
    p::Pattern
    code::Vector
    results::Dict{Node,Any}
    Ctx(p::Pattern) = new(p, {}, Dict{Node,Any}())
end

emit(c::Ctx, ex) = (push(c.code, ex); nothing)
emit_guard(c::Ctx, ex) = emit(c, :( if !$ex; return (false,nothing); end ))

function code_match(p::Pattern)
    c = Ctx(p)
    for g in values(p.guards); evaluate(c, g); end

    bound = Set{Symbol}()
    for b in p.bindings
        if has(bound, b.name)
            emit_guard(c, :( is($(evaluate(c,b.arg)), $(b.name)) ))
        else
            emit(c, :( $(b.name) = $(evaluate(c,b.arg)) ))
            add(bound, b.name)
        end
    end
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

evalguardof(c::Ctx, node::Value) = evaluate(c, c.p.guards[node])


code_match(c::Ctx, v::Arg) = argsym
function code_match(c::Ctx, v::TupleRef) 
    evalguardof(c, v.arg)
    :( $(evaluate(c,v.arg))[$(v.index)] )
end
    
code_match(c::Ctx, g::Guard) = emit_guard(c, code_pred(c, g))

code_pred(c::Ctx,g::Egal) = :(is( $(evaluate(c, g.arg)), $(quot(g.value))))
code_pred(c::Ctx,g::Isa)  = :(isa($(evaluate(c, g.arg)), $(quot(g.typ  ))))

end # module
