
module Dispatch
import Base.add
using Patterns, Toivo
export MethodTable, create_method, dispatch
export ResultsDict, Sequence, sequence!, code_predicate, encoded # temporary

# ==== MethodTable ============================================================

type Method
    sig::Pattern
    f::Function
end

type MethodTable
    name::Symbol
    methods::Vector{Method}
    MethodTable(name::Symbol) = new(name, Method[])
end

function add(mt::MethodTable, m::Method)
    # insert the pattern in ascending topological order, as late as possible
    i = length(mt.methods)+1
    for (k, mk) in enumerate(mt.methods)
        if m.sig.intent <= mk.sig.intent
            if m.sig.intent >= mk.sig.intent
                # equal signature ==> replace
                mt.methods[k] = m
                return
            else
                i = k
                break
            end
        end
    end
    insert(mt.methods, i, m)

    for mk in mt.methods
        lb = m.sig.intent & mk.sig.intent
        if lb === naught; continue; end
        if any([ml.sig.intent == lb for ml in mt.methods]) continue; end
        
        println("Warning: New @pattern method ", mt.name, m.sig)
        println("         is ambiguous with   ", mt.name, mk.sig)
        println("         Make sure ", mt.name, m.sig&mk.sig, " is defined first")
    end
end

function dispatch(mt::MethodTable, args::Tuple)
    for m in mt.methods
        matched, result = m.f(args)
        if matched; return result; end
    end
    error("No matching method found for pattern function $(mt.name)")
end

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
    fdef
end
create_method(p::Pattern, body) = Method(p, eval(code_method(p,body)))


# ---- sequence!: Create evaluation order, instantiate nodes into Result's ----

typealias ResultsDict Dict{Node,Node}
type Sequence
    intent::Intension
    results::ResultsDict
    seq::Vector{Node}

    Sequence(i::Intension, r::ResultsDict) = new(i, r, Node[])
end
Sequence(intent::Intension) = Sequence(intent,   ResultsDict())
Sequence(s::Sequence)       = Sequence(s.intent, copy(s.results))

wrap(node::Guard) = node
wrap(node::Node)  = Result(node)

function sequence!(s::Sequence, node::Node)
    if has(s.results, node)
        newnode = s.results[node]
        if isa(newnode, Result); newnode.nrefs += 1; end
        return
    end

    for dep in depsof(s.intent, node);  sequence!(s, dep)  end
    newnode = s.results[node] = wrap(subs(s.results, node))
    push(s.seq, newnode)
end


# ---- code_match etc: generate code from (instantiated) node sequence --------

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


end # module
