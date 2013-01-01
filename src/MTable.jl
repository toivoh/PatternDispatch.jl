
module MTable
using Meta, PartialOrder

# uses:
# nomethod(Method)
# signatureof(method), signatureof(method, suffix)
# idof(method)
# show_bodyfun(method)
# domainof(method), domainof(M, hullT)
# is_empty_domain(intent)


type MethodTable{M}
    name::Symbol
    top::Node{M}

    comiled::Bool
    f::Function

    function MethodTable(name::Symbol)
        mt = new(name, Node(nomethod(M)), false)
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

show_dispatch(mt::MethodTable, as...) = show_dispatch(OUTPUT_STREAM, mt, as...)
show_dispatch(io::IO, mt::MethodTable) = show_dispatch(io, mt, Tuple)
function show_dispatch{M}(io::IO, mt::MethodTable{M}, Ts::Tuple) 
    if !mt.compiled;  compile!(mt);  end

    println("const ", mt.name, " = (args...)->dispatch(args...)")

    println("\n# ---- Pattern methods: ----")
    methods = methodsof(mt)
    methods = Method[filter(m->(m!=nomethod), methods)...]

    mnames = (Function=>Symbol)[]
    for (id, method) in sort([(idof(m), m) for m in methods])
        if method == nomethod(M);  continue  end

        println(io, "# ", mt.name, signatureof(method))
        mnames[method.body] = mname = symbol(string("match", idof(method)))
        show_bodyfun(io, method, mname)
#         args = keys(method.sig.bindings) # Right order? Does it matter?
#         Base.show_unquoted(io, expr(:function, :($mname($(args...))), 
#                                     method.body_ex))
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

function add(mt::MethodTable, m::Method)
    set_id!(m, (mt.method_counter += 1))
    insert!(mt.top, Node(m))
    
    methods = methodsof(mt)
    for mk in methods
        lb = domainof(m) & domainof(mk)
        if is_empty_domain(lb); continue; end
        if any([domainof(ml) == lb for ml in methods]) continue; end
        
        sig1 = signatureof(m.sig,  "_A")
        sig2 = signatureof(mk.sig, "_B")

        println("Warning: New @pattern method ", mt.name, sig1)
        println("         is ambiguous with   ", mt.name, sig2, '.')
        println("         Make sure ", mt.name, sig1&sig2," is defined first.")
    end

    # todo: only when necessary
    if mt.compiled;  compile!(mt)  end
end

function methodsof(mt::MethodTable)
    ms = ordered_subDAGof(mt.top)
    [m.value for m in ms]
end

function compile!{M}(mt::MethodTable{M})
    mt.compiled = true
    eval(:(let
            const f    = $(quot(mt.f))
            f(args...) = error("No matching pattern method found")
        end))

    # NB: Lists methods in topological order;
    # avoids ambiguity warnings from julia as long
    # as there is no# ambiguity among the patterns.
    methods = methodsof(mt)
    actual_methods = filter(m->(m != nomethod(M)), methods)
    hullTs = Tuple[hullTof(m) for m in actual_methods]
    
    compiled = Set{Tuple}()
    for hullT in reverse(hullTs)
        if has(compiled, hullT); continue end
        add(compiled, hullT)
        compile!(mt, methods, hullT)
    end
end

ltT(S,T) = !(S==T) && (S<:T)
function compile!{M}(mt::MethodTable, methods::Vector{M}, hullT::Tuple)
    top = copyDAG(mt.top)

    # filter out too specific methods
    keep = Set{M}(filter(m->!ltT(hullTof(m), hullT), methods)...)
    @assert !isempty(keep)
    raw_filter!(top, keep)

    # filter out non-questions
    hull = domainof(M, hullT)
    top = simplify!(top, hull)
    
    # create dispatch code using given assumptions and args
    # todo: move some of this into DecisionTree
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
    
    code = code_dispatch(top, results)
    args = {:($argsym::$(quot(T))) for (argsym,T) in zip(argsyms,hullT)}    
    fdef = expr(:function, :( $(mt.name)($(args...)) ), code)
    mt.julia_methods[hullT] = expr(:function, :( dispatch($(args...)) ), code)

    eval(:(let
            const f = $(quot(mt.f))
            f($(args...)) = $code
        end))
end

end # module