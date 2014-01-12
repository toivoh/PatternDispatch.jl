module Macros
export @pattern, code_pattern, @patterns, code_patterns
export show_dispatch
export @qmethod, code_qmethod


using Base.Meta
using ..Patterns
using ..Methods, ..Methods.Method
using ..Inverses
    

split_fdef_error(f) = error("expected function definition, got\n$f")
function split_fdef(fdef::Expr)
    ((fdef.head == :function) || (fdef.head == :(=))) || split_fdef_error(f)
    length(fdef.args) == 2      || split_fdef_error(f)
    signature, body = fdef.args
    isexpr(signature, :call)    || split_fdef_error(f)
    length(signature.args) >= 1 || split_fdef_error(f)
    (signature, body)
end
split_fdef(f::Any) = split_fdef_error(f)


function recode_method(args::Vector, body)
    pattern = :( ($(args...),) )
    rec, argnames = recode_pattern(pattern)
    :( let
        local pattern = $(esc(rec))
        local bodyfun = $(esc(:( function pm($(argnames...)); $body; end )))
#        local bodyfun = $(esc(:(($(argnames...),)->$body)))
        # wrap body in a tuple before quoting it; should avoid interpolation?
        Method(pattern, bodyfun, $(quot(argnames)), $(quot((body,)))[1])
    end )
end

function code_qmethod(fdef)
    sig, body = split_fdef(fdef)
    recode_method(sig.args[2:end], body)
end
macro qmethod(ex)
    code_qmethod(ex)
end

function code_patterns(blockex)
    @assert isexpr(blockex, :block)
    code = {}
    for fdef in blockex.args
        if isexpr(fdef, :line) || isa(fdef, LineNumberNode); continue; end
        push!(code, code_pattern(fdef)) # todo: let code_pattern now it's invoked from @patterns?
    end
    quote
        $(code...)
    end
end

macro patterns(ex)
    code_patterns(ex)
end

type PatternFunction
    mt::MethodTable
    f::Function # dispatch function

    function PatternFunction(name::Symbol)
        f = @eval let
            $name(args...) = error($("No methods defined for pattern function $name"))
        end
        new(MethodTable(name), f)
    end
end

function Methods.addmethod!(pf::PatternFunction, m::Method)
    addmethod!(pf.mt, m)
    # todo: only compile when needed
    compile!(pf)
end

function compile!(pf::PatternFunction)
    fdef = encode(pf.mt)
    @eval let
        const $(pf.mt.name) = $(quot(pf.f))
        $fdef
    end
end

const pattern_functions = Dict{Function,PatternFunction}()

function create_pattern_function(name::Symbol, method::Method)
    pf = PatternFunction(name)
    f = @eval (args...)->$(pf.f)(args...)            
    pattern_functions[f] = pf
    addmethod!(pf, method)
    f
end
function add_pattern_method!(f::Function, method::Method)
    if !haskey(pattern_functions, f); error("$f is not a pattern function"); end
    pf = pattern_functions[f]
    addmethod!(pf, method)
end

function code_methoddef(fname::Symbol, args::Vector, body)
    f = esc(fname)
    mex = recode_method(args, body)
    # NB: this code can not declare any locals at top level since several copies may be
    # emitted in one block by @patterns
    quote
        method = $mex

        wasbound, f = try; (true, $f)
        catch e;           (false, nothing)
        end
        if !wasbound; const $f = create_pattern_function($(quot(fname)), method)
        else;         add_pattern_method!(f, method)
        end        
    end
end

function code_pattern(fdef)
    sig, body = split_fdef(fdef)
    fex = sig.args[1]
    if isexpr(fex, :macrocall, 2) && fex.args[1] === symbol("@inverse")
        code_invdef(sig, body)
    elseif isa(fex, Symbol)
        code_methoddef(fex, sig.args[2:end], body)
    else
        error("@pattern: unrecognized function definition $fdef")
    end
end

macro pattern(fdef)
    code_pattern(fdef)
end


show_dispatch(f::Union(Function,PatternFunction), args...) = show_dispatch(STDOUT, f, args...)
function show_dispatch(io::IO, f::Function, args...)
    if !haskey(pattern_functions, f); error("$f is not a pattern function"); end
    show_dispatch(io, pattern_functions[f], args...)
end

function show_dispatch(io::IO, pf::PatternFunction)
    mt = pf.mt
    println("const ", mt.name, " = (args...)->dispatch(args...)")

    println("\n# ---- Pattern methods: ----")
    methods = methodsof(mt)
    mnames = (Function=>Symbol)[]
    for (id, method) in sort([(m.id, m) for m in methods])
        if method.f == nothing; continue end

        println(io, "# ", mt.name, method.p_orig)
        mname = symbol(string("match", method.id))
        mnames[method.f] = mname

        Base.show_unquoted(io, Expr(:function, :($mname($(method.argnames...))), method.body_ex))
        print(io,"\n\n")
    end
    
end

end # module
