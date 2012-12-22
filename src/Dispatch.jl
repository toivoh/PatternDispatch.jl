
module Dispatch
import Base.add
using Patterns, Encode, Toivo
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

end # module
