
module Intern
using ..Meta
export @interned, @get!  # shouldn't need to export @get!

const new_interned = gensym("new_interned")

function replace_new(ex::Expr)
    if ex.head === :quote; return ex; end

    args = Any[replace_new(arg) for arg in ex.args]
    if (ex.head === :call) && args[1] == :new
        return Expr(:call, new_interned, args[2:end]...)
    end
    Expr(ex.head, args...)
end
replace_new(ex) = ex

macro interned(ex)
    code_interned(ex)
end
function code_interned(ex)
    @expect is_expr(ex, :type, 3)
    imm, typesig, typebody = ex.args    
    typeex = (is_expr(typesig, :(<:), 2) ? typesig.args[1] : typesig)
    typename =   (is_expr(typeex, :curly) ? typeex.args[1] : typeex)::Symbol
    typeparams = (is_expr(typeex, :curly) ? typeex.args[2:end] : [])

    fields, types, sigs, defs = Symbol[], [], [], []
    needs_default_constructor = true
    for def in typebody.args
        if isa(def, Symbol)
            push!(fields, def)
            push!(types,  quot(Any))
            push!(sigs, def)
        elseif is_expr(def, :(::), 2)
            push!(fields, def.args[1])
            push!(types,  def.args[2])            
            push!(sigs, def)
        elseif is_fdef(def)
            sig, body = split_fdef(def)
            if sig.args[1] === typename  # constructor
                needs_default_constructor = false
                body = replace_new(body)
                def = :($sig=$body)
            end
        end
        push!(defs, def)    
    end
    
    objects = ObjectIdDict()
    push!(defs, :($new_interned{$(typeparams...)}($(sigs...)) = 
                  @get!($(quot(objects)),($(fields...),), new{$(typeparams...)}($(fields...))) ))
    if needs_default_constructor
        push!(defs, :( $typename($(sigs...)) = $new_interned($(fields...)) ))
    end
    esc(Expr(:type, imm, typesig, Expr(:block, defs...)))
end

end
