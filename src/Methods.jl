
module Methods
import Base.add, Base.>=, Base.&
import Dispatch.domainof, Dispatch.signatureof, Dispatch.make_namer
import Dispatch.is_empty_domain, Dispatch.hullof
import Nodes
using Meta, PartialOrder, Patterns, Dispatch, Encode

export MethodTable, Method, show_dispatch


# ---- Method -----------------------------------------------------------------

type Method
    sig::Pattern
    bindings::Vector{Node}
    body::Union(Function,Nothing)
    body_ex
    hullT::Tuple
    id::Int

    function Method(sig::Pattern, bs, body, body_ex)
        new(sig, bs, body, body_ex, Nodes.julia_signature_of(sig))
    end
end

const nomethod = Method(Pattern(anything), Node[], nothing, nothing)

>=(x::Method, y::Method) = x.sig.intent >= y.sig.intent
#==(x::Method, y::Method) = x.sig.intent == y.sig.intent
(&)(m::Method,  i::Intension) = m.sig.intent & i

domainof(m::Method) = m.sig.intent
hullof(m::Method)   = intension(m.hullT)
signatureof(m::Method)         = m.sig
signatureof(m::Method, suffix) = suffix_bindings(m.sig, suffix)

function make_namer(methods::Vector{Method})
    (node::Node)->begin        
        for method in methods
            rb = method.sig.rev_bindings
            if has(rb, node)
                return symbol(string(rb[node], '_', method.id))
            end
        end
        nothing
    end
end


is_empty_domain(domain::Intension) = (domain === naught)


# ---- MethodTable ------------------------------------------------------------

typealias MethodNode PartialOrder.Node{Method}

type MethodTable
    name::Symbol
    top::MethodNode

    compiled::Bool
    julia_methods::Dict{Tuple,Any}
    method_counter::Int
    f::Function

    function MethodTable(name::Symbol) 
        mt = new(name, MethodNode(nomethod), false, (Tuple=>Any)[], 0)
        mt.f = eval(:(let
                function $name(args...)
                    compile!($(quot(mt)))
                    $(quot(mt)).f(args...)
                end
                $name
            end))
        mt
    end
end

methodsof(mt::MethodTable) = [m.value for m in ordered_subDAGof(mt.top)]

function add(mt::MethodTable, m::Method)
    m.id = (mt.method_counter += 1)
    addmethod!(mt.top, mt.name, m)

    # todo: recompile only when necessary (when is that?)
    if mt.compiled;  compile!(mt)  end
end

function compile!(mt::MethodTable)
    mt.compiled = true
    eval(:(let
            const f = $(quot(mt.f))
            f(args...) = error("No matching pattern method found")
        end))

    # NB: Lists methods in topological order;
    # avoids ambiguity warnings from julia as long
    # as there is no ambiguity among the patterns.
    methods = methodsof(mt)
    hullTs = Tuple[m.hullT for m in filter(m->(m != nomethod), methods)]
    
    compiled = Set{Tuple}()
    for hullT in reverse(hullTs)
        if has(compiled, hullT); continue end
        add(compiled, hullT)
        compile!(mt, methods, hullT)
    end
end

function compile!(mt::MethodTable, methods::Vector{Method},hullT::Tuple)
    hull = intension(hullT)
    top = simplify(mt.top, hull)
    dtree = build_dtree(top)
    
    # create dispatch code using given assumptions and args
    # todo: Move results manipulation into Encode
    results = ResultsDict()
    for pred in predsof(hull);  preguard!(results, Guard(pred));  end

    argsyms = {}
    for k=1:length(hullT)
        node, name = Nodes.tupref(Nodes.argnode, k), nothing
        for method in methods
            rb = method.sig.rev_bindings
            if has(rb, node)
                name = symbol(string(rb[node], '_', method.id))
                break
            end
        end
        if name === nothing;  name = symbol("arg$k");  end
        
        push(argsyms, name)
        provide!(results, node, name)
    end
    
    seq_dispatch!(results, dtree)
    code = code_dispatch(dtree)


    args = {:($argsym::$(quot(T))) for (argsym,T) in zip(argsyms,hullT)}    
    fdef = expr(:function, :( $(mt.name)($(args...)) ), code)
    mt.julia_methods[hullT] = expr(:function, :( dispatch($(args...)) ), code)

    eval(:(let
            const f = $(quot(mt.f))
            f($(args...)) = $code
        end))
end

show_dispatch(mt::MethodTable, args...) = show_dispatch(OUTPUT_STREAM, 
                                                        mt, args...)
show_dispatch(io::IO, mt::MethodTable) = show_dispatch(io, mt, Tuple)
function show_dispatch(io::IO, mt::MethodTable, Ts::Tuple) 
    if !mt.compiled;  compile!(mt)  end

    println("const ", mt.name, " = (args...)->dispatch(args...)")

    println("\n# ---- Pattern methods: ----")
    methods = methodsof(mt)
    mnames = (Function=>Symbol)[]
    for (id, method) in sort([(m.id, m) for m in methods])
        if method === nomethod; continue end

        println(io, "# ", mt.name, method.sig)
        mname = symbol(string("match", method.id))
        mnames[method.body] = mname

        args = keys(method.sig.bindings) # Right order? Does it matter?
        Base.show_unquoted(io, expr(:function, :($mname($(args...))), 
                                    method.body_ex))
        print(io,"\n\n")
    end

    subs_invocation(ex) = begin
        if is_expr(ex, :quote) && has(mnames, ex.args[1]); mnames[ex.args[1]]
        else; nothing
        end
    end

    println("# ---- Dispatch methods: ----")
    for (f_Ts, fdef) in mt.julia_methods
        if f_Ts <: Ts
            Base.show_unquoted(io, subs_ex(subs_invocation, fdef))
            print(io, "\n\n")
        end
    end
end

end # module
