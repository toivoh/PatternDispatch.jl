
module Immutable
using Meta
export @immutable, @get!  # shouldn't need to export @get!

macro immutable(ex)
    code_immutable(ex)
end
function code_immutable(ex)
    @expect is_expr(ex, :type, 2)
    typesig, body = ex.args    
    typeex = (is_expr(typesig, :(<:), 2) ? typesig.args[1] : typesig)
    typename = (is_expr(typeex, :curly) ? typeex.args[1] : typeex)::Symbol
    fields, types, sigs = Symbol[], {}, {}
    for arg in body.args
        if isa(arg, Symbol)
            push(fields, arg)
            push(types,  quot(Any))
            push(sigs, arg)
        elseif is_expr(arg, :(::), 2)
            push(fields, arg.args[1])
            push(types,  arg.args[2])            
            push(sigs, arg)
        end
    end
    
    instances = ObjectIdDict()
    newimm = gensym("new")
    esc(quote
        type $typesig
            $(body.args...)
            $newimm($(sigs...)) = @get!($(quot(instances)), ($(fields...),),
                                          new($(fields...)))
            $typename($(sigs...)) = $newimm($(fields...))
        end
    end)
end

end
