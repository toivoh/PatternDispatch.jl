module Macros
export @patterns, code_patterns
export @qmethod, code_qmethod, @qmethod_table, code_qmethod_table
export @pattern, code_pattern # currently reexporting from Inverses


using Base.Meta
using Patterns
using Methods, Methods.Method
using Inverses
using Toivo.split_fdef


function recode_method(fdef)
    sig, body = split_fdef(fdef)
    pattern = :( ($(sig.args[2:end]...),) )
    rec, argnames = recode_pattern(pattern)
    ex = :( let
        local pattern = $(esc(rec))
        local bodyfun = $(esc(:(($(argnames...),)->$body)))
        Method(pattern, bodyfun, $(quot(argnames)))
    end )
    ex, sig.args[1]
end

code_qmethod(fdef) = recode_method(fdef)[1]
macro qmethod(ex)
    code_qmethod(ex)
end

function code_qmethod_table(blockex)
    @assert isexpr(blockex, :block)
    code = {}
    name = nothing
    for fdef in blockex.args
        if isexpr(fdef, :line) || isa(fdef, LineNumberNode); continue; end

        method_ex, fname = recode_method(fdef)

        if name == nothing; name = fname
        else                @assert name == fname
        end

        push!(code, :( addmethod!(mt, $method_ex) ))
    end
    @assert name != :nothing
    :( let
        local mt = MethodTable($(quot(name)))
        $(code...)
        mt
    end )
end
macro qmethod_table(ex)
    code_qmethod_table(ex)
end

function code_patterns(blockex)
    mt_ex = code_qmethod_table(blockex)
    :( let
        local mt = $mt_ex
        local fdef = encode(mt)
#        @show fdef
        $(esc(:eval))(fdef)
    end )
end

macro patterns(ex)
    code_patterns(ex)
end


end # module
