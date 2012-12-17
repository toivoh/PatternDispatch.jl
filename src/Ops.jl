
module Ops
using Graph, Toivo
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<
export simplify, unbind


# ==== simplify ===============================================================

function simplify(p::Pattern)
    # several Egal on same node
    # several Isa  on same node
    # Isa on nodes with Egal on them

    gs = Dict{Value,Guard}()
    for g in p.guards
        if !isa(g, Bind)
            node = g.arg
            new_g = has(gs, node) ? (g & gs[node]) : g
            if new_g === never
                return nullpat
            end
            gs[node] = new_g
        end
    end
    guards = Guard[]
    for g in p.guards
        if isa(g, Bind)
            push(guards, g)
        else
            node = g.arg
            if has(gs, node)
                push(guards, gs[node])
                del(gs, node)
            end
        end
    end

    Pattern(guards)
end


(&)(p::Pattern, q::Pattern) = simplify(Pattern([p.guards, q.guards]))

unbind(p::Pattern) = Pattern(Guard[filter(g->!isa(g,Bind), p.guards)...])

function isequal(p::Pattern, q::Pattern)
    p, q = simplify(p), simplify(q)
    return Set{Guard}(p.guards...) == Set{Guard}(q.guards...)
end

>=(p::Pattern, q::Pattern) = (p & q) == q
>(p::Pattern, q::Pattern)  = (p >= q) && (p != q)

<=(p::Pattern, q::Pattern) = q >= p
<(p::Pattern, q::Pattern)  = q >  p

end # module

