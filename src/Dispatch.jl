
module Dispatch
import Base.add
using Patterns, Toivo
export MethodTable, create_method, dispatch


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

function code_metod(p::Pattern, body)
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
    @show fdef
    fdef
end
create_method(p::Pattern, body) = Method(p, eval(code_metod(p,body)))


# ---- sequence: construct an evaluation order --------------------------------

type Seq
    intent::Intension
    evaluated::Dict{Node,Int}
    guarded::Set{Predicate}
    seq::Vector{Vector{Node}}

    Seq(i::Intension) = new(i, Dict{Node,Int}(), Set{Predicate}(), Vector{Node}[Node[]])
end

function sequence_guard!(c::Seq, pred::Predicate)
    if has(c.guarded, pred); return; end
    add(c.guarded, pred)

    sequence!(c, pred)
    s = c.seq[end]
    if length(s) == 0 || s[end] != pred; push(s, pred); end
    push(c.seq, Node[])
end

function sequence!(c::Seq, node::Node)
    if has(c.evaluated, node)
        c.evaluated[node] += 1
        return
    end

    for dep in depsof(node);  sequence!(c, dep)      end
    for g in guardsof(c.intent, node);  sequence_guard!(c, g)  end
    c.evaluated[node] = 1
    push(c.seq[end], node)
end

type Encode
    evaluated::Dict{Node,Int}
    results::Dict{Node,Any}
    Encode(evaluated::Dict{Node,Int}) = new(evaluated, Dict{Node,Any}())
end

function encode!(c::Encode, nodes::Vector, ispred::Bool)
    exprs = {}
    for node in nodes
        ex = encode!(c, node)        
        if ex != nothing; push(exprs, ex); end
    end
    if ispred
        push(exprs, c.results[nodes[end]])
    end
    exprs
end
function encode!(c::Encode, node::Node)
    if has(c.results, node); return c.results[node] end
    ex = encode(c.results, node)
    if isa(ex, Symbol) || c.evaluated[node] == 1
        c.results[node] = ex
        nothing
    else
        var = gensym("t")
        c.results[node] = var
        :( $var = $ex )
    end
end

wrap(exprs::Vector) = length(exprs)==1 ? exprs[1] : expr(:block, exprs)

function code_match(p::Pattern)
    c = Seq(p.intent)
    for g in guardsof(p.intent);    sequence_guard!(c, g)  end
    for node in values(p.bindings); sequence!(c, node)     end

    enc = Encode(c.evaluated)
    preds = [wrap(encode!(enc, seq, true)) for seq in c.seq[1:end-1]]
    prebind = encode!(enc, c.seq[end], false)
    binds = { :( $name = $(enc.results[node])) for (name, node) in p.bindings }
    bind = vcat(prebind, binds)

    if isempty(preds)
        pred = quot(true)
    else
        pred = preds[1]
        for factor in preds[2:end]; pred = :($pred && $factor); end
    end
    pred, bind
end


end # module
