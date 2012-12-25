
module Immutable
using Meta
export @immutable, @get!  # shouldn't need to export @get!

macro immutable(ex)
    code_immutable(ex)
end
function code_immutable(ex)
    @expect is_expr(ex, :type, 2)
    sig, body = ex.args    
    typename = (is_expr(sig, :(<:), 2) ? sig.args[1] : sig)::Symbol 
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
    
    instances = Dict()
    esc(quote
        type $sig
            $(body.args...)
            $typename($(sigs...)) = @get!($(quot(instances)), ($(fields...),),
                                          new($(fields...)))
        end
    end)
end

end
