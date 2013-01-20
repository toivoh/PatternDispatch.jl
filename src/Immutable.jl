
module Immutable
using Meta
export @immutable, @get!  # shouldn't need to export @get!

const newimm = gensym("newimm")

function replace_new(ex::Expr)
    if ex.head === :quote; return ex; end

    args = {replace_new(arg) for arg in ex.args}
    if (ex.head === :call) && args[1] == :new
        return expr(:call, newimm, args[2:end]...)
    end
    expr(ex.head, args)
end
replace_new(ex) = ex

macro immutable(ex)
    code_immutable(ex)
end
function code_immutable(ex)
    @expect is_expr(ex, :type, 2)
    typesig, typebody = ex.args    
    typeex = (is_expr(typesig, :(<:), 2) ? typesig.args[1] : typesig)
    typename = (is_expr(typeex, :curly) ? typeex.args[1] : typeex)::Symbol

    fields, types, sigs, defs = Symbol[], {}, {}, {}
    needs_default_constructor = true
    for def in typebody.args
        if isa(def, Symbol)
            push(fields, def)
            push(types,  quot(Any))
            push(sigs, def)
        elseif is_expr(def, :(::), 2)
            push(fields, def.args[1])
            push(types,  def.args[2])            
            push(sigs, def)
        elseif is_fdef(def)
            sig, body = split_fdef(def)
            if sig.args[1] === typename  # constructor
                needs_default_constructor = false
                body = replace_new(body)
                def = :($sig=$body)
            end
        end
        push(defs, def)    
    end
    
    objects = ObjectIdDict()
    push(defs, :($newimm($(sigs...)) = @get!($(quot(objects)), ($(fields...),),
                                             new($(fields...))) ))
    if needs_default_constructor
        push(defs, :( $typename($(sigs...)) = $newimm($(fields...)) ))
    end
    esc(expr(:type, typesig, expr(:block, defs)))
end

end
