load("Toivo.jl")
load("Debug.jl")

module PatternDispatch
using Toivo, Debug
export @immutable, @get!
export @pattern

include(find_in_path("PatternDispatch/src/immutable.jl"))


abstract Node
abstract Value <: Node
abstract Guard <: Node

type Arg      <: Value; end
const argnode = Arg()
const argsym  = gensym("arg")

@immutable type TupleRef   <: Value;  arg::Value; index::Int;    end
@immutable type Bind       <: Guard;  arg::Value; name::Symbol;  end
@immutable type Egal       <: Guard;  arg::Value; value;         end
@immutable type TypeAssert <: Guard;  arg::Value; typ;           end
@immutable type IsTuple    <: Guard;  arg::Value; n::Int;        end


type Pattern
    guards::Vector{Guard}
end


# ==== recode: function signature -> Pattern creating AST =====================

type Recode
    code::Vector
    guards::Vector
    Recode() = new({}, {})
end

function recode(ex::Expr)
    r = Recode()
    recode(r, quot(Arg()), ex)
    quote
        $(r.code...)
        Pattern(Guard[$(r.guards...)])
    end
end

recode(c::Recode, arg, ex)         = push(c.guards, :(Egal($arg, $(quot(ex)))))
recode(c::Recode, arg, ex::Symbol) = push(c.guards, :(Bind($arg, $(quot(ex)))))
function recode(c::Recode, arg, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head === :(::)
        @assert 1 <= nargs <= 2
        if nargs == 1
            push(c.guards, :( TypeAssert($arg, $(esc(args[1]))) ))
        else
            push(c.guards, :( TypeAssert($arg, $(esc(args[2]))) ))
            recode(c, arg, args[1])
        end
    elseif head === :tuple
        push(c.guards, :( IsTuple($arg, $nargs) ))
        for (k, p) in enumerate(args)
            node = gensym("e$k")
            push(c.code, :( $node = TupleRef($arg, $k) ))
            recode(c, node, p)
        end
    elseif head === :call && args[1] == :~
        for p in args[2:end]; recode(c, arg, p); end
    else
        error("recode: unimplemented: ex = $ex")
    end
end


# ==== code_match: Pattern -> matching code ===================================

type Ctx
    code::Vector
    values::Dict{Value,Symbol}
    bound::Set{Symbol}
    Ctx() = new({}, Dict{Value,Symbol}(), Set{Symbol}())
end

emit(c::Ctx, ex) = (push(c.code, ex); nothing)
emit_guard(c::Ctx, ex) = emit(c, :( if !$ex; return (false,nothing); end ))

function code_match(p::Pattern)
    c = Ctx()
    for g in p.guards
        code_match(c, g)
    end
    quote; $(c.code...); end
end

function code_match(c::Ctx, v::Value)
    if has(c.values, v)
        c.values[v]
    else
        val = gensym("v")
        emit(c, :( $val = $(code_val(c, v)) ))
        c.values[v] = val
    end
end

code_val(c::Ctx, v::Arg)      = argsym
code_val(c::Ctx, v::TupleRef) = :( $(code_match(c,v.arg))[$(v.index)] )

function code_match(c::Ctx, g::Bind)
    if has(c.bound, g.name)
        emit_guard(c, :( is($(code_match(c,g.arg)), $(g.name)) ))
    else
        emit(c, :( $(g.name) = $(code_match(c,g.arg)) ))
    end
end
code_match(c::Ctx, g::Guard) = emit_guard(c, code_pred(c, g))

code_pred(c::Ctx,g::Egal)      = :(is($(code_match(c,g.arg)),$(quot(g.value))))
code_pred(c::Ctx,g::TypeAssert)= :(isa($(code_match(c,g.arg)),$(quot(g.typ))))
function code_pred(c::Ctx, g::IsTuple)
    r = code_match(c, g.arg)
    :( isa($r, Tuple) && length($r) == $(g.n) )
end


# ==== MethodTable ============================================================

type MethodTable
    name::Symbol
    methods::Vector{Function}
    MethodTable(name::Symbol) = new(name, Function[])
end

add(mt::MethodTable, m::Function) = (push(mt.methods, m); nothing)

function dispatch(mt::MethodTable, args::Tuple)
    for m in mt.methods
        matched, result = m(args)
        if matched; return result; end
    end
    error("No matching method found for pattern function $(mt.name)")
end


function create_method(p::Pattern, body)
    code = code_match(p)
    @eval $argsym->begin
        $(code)
        (true, $body)
    end
end

# ==== @pattern ===============================================================

const method_tables = Dict{Function, MethodTable}()

macro pattern(ex)
    code_pattern(ex)
end

function code_pattern(ex)
    sig, body = split_fdef(ex)
    @expect is_expr(sig, :call)
    fname, args = sig.args[1], sig.args[2:end]
    psig = :($(args...),)
    p_ex = recode(psig)
    
    f = esc(fname)
    quote       
        wasbound = try
            f = $f
            true
        catch e
            false
        end

        if !wasbound
            mt = MethodTable($(quot(fname)))
            const $f = (args...)->dispatch(mt, args)
            method_tables[$f] = mt
            println($("$fname was unbound"))
        else
            if !has(method_tables, $f)
                error($("$fname is not a pattern function"))
            end
            mt = method_tables[$f]
            println($("$fname was a pattern function"))
        end

        method = create_method($p_ex, $(quot(body)))
        add(mt, method)
    end
end

end # module
