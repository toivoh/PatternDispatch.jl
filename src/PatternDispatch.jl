load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
import Base.&, Base.isequal, Base.>=, Base.>, Base.<=, Base.<
export @pattern, @qpat, @spat, simplify, unbind

include(find_in_path("PatternDispatch/src/Immutable.jl"))
include(find_in_path("PatternDispatch/src/Graph.jl"))
include(find_in_path("PatternDispatch/src/Recode.jl"))
include(find_in_path("PatternDispatch/src/CodeMatch.jl"))
include(find_in_path("PatternDispatch/src/Macros.jl"))
using Graph, Recode, CodeMatch
using Macros


# ==== simplify ===============================================================

(&)(e::Egal, f::Egal)= (@assert e.arg===f.arg; e.value===f.value ?   e : never)
(&)(e::Egal, t::Isa) = (@assert e.arg===t.arg; isa(e.value, t.typ) ? e : never)
(&)(t::Isa, e::Egal) = e & t
function (&)(s::Isa, t::Isa) 
    @assert s.arg===t.arg
    T = tintersect(s.typ, t.typ)
    T === None ? never : Isa(s.arg, T)
end

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





macro qpat(ex)
    recode(ex)
end
macro spat(ex)
    quote
        simplify($(recode(ex)))
    end
end

end # module
