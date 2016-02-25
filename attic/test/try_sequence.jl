module TrySequence
#import PatternDispatch.Patterns.depsof, PatternDispatch.Patterns.subs
#using PatternDispatch.Immutable, 
import PatternDispatch
using PatternDispatch.Patterns, PatternDispatch.Recode, Toivo
#import PatternDispatch.Patterns.TupleRef


# ---- Stuff for Patterns.jl --------------------------------------------------

#@in PatternDispatch.Patterns begin
#end

# ---- sequence! -------------------------------------------------------------
 
type Sequence
    intent::Intension
    results::Dict{Node,Node}
    seq::Vector{Node}
end
Sequence(intent::Intension) = Sequence(intent,   Dict{Node,Node}(), Node[])
Sequence(s::Sequence)       = Sequence(s.intent, copy(s.results),     Node[])

wrap(node::Guard) = node
wrap(node::Node)  = Result(node)

function sequence!(s::Sequence, node::Node)
    @show node
    if has(s.results, node)
        newnode = s.results[node]
        if isa(newnode, Result); newnode.nrefs += 1; end
        return
    end

    for dep in depsof(s.intent, node);  sequence!(s, dep)  end
    newnode = s.results[node] = wrap(subs(s.results, node))
    push(s.seq, newnode)
end


# ---- code_match etc --------------------------------------------------------

function code_match(p::Pattern)
    sg = Sequence(p.intent)
    for g in guardsof(p.intent);    sequence!(sg, Guard(g));     end
    sb = Sequence(sg)
    for node in values(p.bindings); sequence!(sb, node);  end
    
    pred = code_predicate(sg.seq)
    prebind = encoded(sb.seq)
    binds = { :( $name = $(sb.results[node].ex)) for (name,node) in p.bindings }
    bind = vcat(prebind, binds)
    
    pred, bind
end

function code_predicate(seq::Vector{Node})
    code = {}
    pred = nothing
    for node in seq
        if isa(node, Guard)
            factor = isempty(code) ? node.pred.ex :  quote; $(code...); $(node.pred.ex) end
            pred = pred === nothing ? factor : (:($pred && $factor))
            code = {}
        else
            encode!(code, node)
        end
    end
    pred
end

function encoded(seq::Vector{Node})
    code = {}
    for node in seq;  encode!(code, node);  end
    code
end

encode!(code::Vector, ::Guard) = error("Undefined!")
function encode!(code::Vector, node::Result)
    if node.ex != nothing;  return  end
    ex = encode(node.node)

    if isa(ex, Symbol) || node.nrefs == 1
        node.ex = ex
    else
        var = gensym("t")
        node.ex = var
        push(code, :( $var = $ex ))
    end
end


# ---- test code --------------------------------------------------------------

function code_method(p::Pattern, body)
    pred, bind = code_match(p)
    fdef = :($argsym->begin
        if $pred
            $(bind...)
            (true, $body)
        else
            (false, nothing)
        end 
    end)
    @show p
    @show pred
    @show bind
    @show fdef
    fdef
end

code_method((@qpat (x::Int,)), :(x^2))


end # module