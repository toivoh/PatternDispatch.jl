module Patterns
export Pattern
export @qpat, code_qpat, recode_pattern

using Base.Meta.quot
using ..Ops
using ..DAGs, ..PatternDAGs
using ..Recode
import ..Common: emit!, calc!, branch!, reemit!
import Base: <=, >=, <, >, ==, &


type Pattern
    g::Graph
    bindings::Dict{Symbol,Node}
    argkeys::Vector{Symbol}

    Pattern() = new(Graph(), (Symbol=>Node)[])
    function Pattern(p::Pattern, suffix::String)
        bindings = (Symbol=>Node)[symbol("$key$suffix") => node for (key,node) in p.bindings]
        new(p.g, bindings, Symbol[])
    end
end

Base.show(io::IO, p::Pattern) = show_pattern(io, p)

emit!(p::Pattern, head::Head, args...) = emit!(p.g, head, args...)
calc!(p::Pattern, head::Calc, args...) = calc!(p.g, head, args...)

function emit!(p::Pattern, b::Binding, value::Node)
    if haskey(p.bindings, b.key); error("Repeated binding")
#equate!(p.g, p.bindings[b.key], value)
    else                          p.bindings[b.key] = value
    end
end

branch!(p::Pattern) = (q = Pattern(); reemit!(q, p); q)

function finish!(p::Pattern)
    p.argkeys = collect(Symbol, keys(p.bindings))
    for key in p.argkeys; p.bindings[key] = primary_rep(p.bindings[key]); end
end

>=(p::Pattern, q::Pattern) = q.g <= p.g
>( p::Pattern, q::Pattern) = (p >= q) && !(q >= p) # (p >= q) && (p != q)
==(p::Pattern, q::Pattern) = (p >= q) && (q >= p)
<=(p::Pattern, q::Pattern) = q >= p
<( p::Pattern, q::Pattern) = q >  p

(&)(p1::Pattern, p2::Pattern) = (p = Pattern(); reemit!(p, p1); reemit!(p, p2); p)


recode_pattern(ex) = recode(ex, :( $(quot(Pattern))() ))
code_qpat(ex) = recode_pattern(ex)[1]
macro qpat(ex)
    esc(code_qpat(ex))
end



immutable PShow
    io::IO
    p::Pattern
    names::Dict{Node,Vector{Symbol}}
    shown::Set{Node}
end

function show_pattern(io::IO, p::Pattern)
    if nevermatches(p.g)
        print(io, "::None")
        return
    end

    # Create mapping node => names
    names = (Node=>Vector{Symbol})[]
    for (name, node) in p.bindings
        node = primary_rep(node)
        if haskey(names, node); push!(names[node], name)
        else                    names[node] = Symbol[name]
        end
    end
    
    sh = PShow(io, p, names, Set{Node}())
    show_pattern(sh, p.g[keyof(Arg())])

    for node in nodesof(p.g)
        # This might not catch all cases of unprinted pattern parts.
        # What would?
        if !isa(node, Node{Source}) && !(node in sh.shown) 
            error("Failed to show node $node")
#            println("Failed to show node $node")
        end
    end
end

function show_pattern(sh::PShow, node::Node)
    if !isprimary(node)
        push!(sh.shown, node)
        node = primary_rep(node)
    end

    tilde=false

    if haskey(sh.names, node)
        for name in sh.names[node]
            if tilde; print(sh.io,'~'); end
            print(sh.io, name)
            tilde = true
            if node in sh.shown; break; end
        end
    end

    push!(sh.shown, node)

    for (user,k) in usesof(node)
        if !(user in sh.shown)
            tilde = bool(tilde | show_pattern(sh, tilde, user, node))
        end
    end

    if isa(node, Node{Source})
        if tilde; print(sh.io,'~'); end
        show(sh.io, valueof(node))
    end
end

function show_pattern(sh::PShow, tilde::Bool, node::Node{TypeGuard}, arg::Node)
    push!(sh.shown, node)
    T = Tof(node)
    if isa(arg, Node{Source}) && T != None; return false; end
    printT = true

    if isa(T, Tuple) && !(T[length(T)] <: Vararg)
        if tilde; print(sh.io,'~'); end

        n = length(T)
        if NTuple{n} <: T; printT = false; end

        print(sh.io, '(')
        for k=1:n
            key = keyof(TupleRef(k), arg)
            if haskey(sh.p.g, key); show_pattern(sh, sh.p.g[key]); end 
            print(sh.io, ',')
            if k < n; print(sh.io, ' '); end
        end
        print(sh.io, ')')            
    end
    if printT; print(sh.io, "::", T); end
    return true
end

show_pattern(sh::PShow, tilde::Bool, node::Node{TupleRef}, arg::Node) = 0

function show_pattern(sh::PShow, tilde::Bool, node::Node{Inv}, arg::Node)
    if !(arg === argsof(node)[1]); return false; end

    push!(sh.shown, node)
    if tilde; print(sh.io, '~'); end
    # todo: safer way to print inverse functions nicely
    print(sh.io, headof(node).f)
    show_pattern(sh, node)
    return true
end

function show_pattern(sh::PShow, tilde::Bool, node::Node{InvVector}, arg::Node)
    if !(arg === argsof(node)[1]); return false; end

    push!(sh.shown, node)
    if tilde; print(sh.io, '~'); end
    print(sh.io, '[')
    show_pattern(sh, node)
    print(sh.io, "...]")
    return true
end

function reemit!(dest, p::Pattern)
    map = reemit!(dest, p.g)
    for (key, node) in p.bindings; emit!(dest, Binding(key), map[node]); end
    map
end

function reemit!(dest, p::Pattern, suffix::String)
    map = reemit!(dest, p.g)
    for (key, node) in p.bindings
        emit!(dest, Binding(symbol(string(key,suffix))), map[node])
    end
    map
end


end # module
