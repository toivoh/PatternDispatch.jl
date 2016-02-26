
module Meta
export quot, is_expr, is_fdef, split_fdef, subs_ex, @expect, @get!


macro expect(pred)
    quote
        $(esc(pred)) ? nothing : error(
          $(string("expected: ", sprint(Base.show_unquoted, pred)", == true")))
    end
end

# ---- Metaprogramming --------------------------------------------------------

quot(ex) = Expr(:quote, ex)

is_expr(ex::Expr, head)          = ex.head === head
is_expr(ex::Expr, heads::Set)    = ex.head in heads
is_expr(ex::Expr, heads::Vector) = ex.head in heads
is_expr(ex,       head)          = false
is_expr(ex,       head, n::Int)  = is_expr(ex, head) && length(ex.args) == n

function subs_ex(subs::Function, ex)
    s = subs(ex)
    s === nothing ? subsubs_ex(subs, ex) : s
end

subsubs_ex(subs::Function, ex) = ex
function subsubs_ex(subs::Function, ex::Expr)
    ex.head === :quote ? ex : Expr(ex.head, Any[subs_ex(subs,a) for a in ex.args]...)
end

function is_fdef(ex::Expr) 
    is_expr(ex,:function,2) || (is_expr(ex,:(=),2)&&is_expr(ex.args[1],:call))
end
is_fdef(ex) = false

# Return the signature and body from a named method definition, either syntax.
# E.g. split_fdef( :( f(x) = x^2) ) == (:(f(x)), :(x^2))
function split_fdef(fdef::Expr)
    @expect (fdef.head == :function) || (fdef.head == :(=))
    @expect length(fdef.args) == 2
    signature, body = fdef.args
    @expect is_expr(signature, :call)
    @expect length(signature.args) >= 1
    (signature, body)
end
split_fdef(f::Any) = error("split_fdef: expected function definition, got\n$f")


# ---- Other stuff (todo: move?) ---------------------------------------------

macro get!(d, k, default)
    quote
        d, k = $(esc(d)), $(esc(k))
        haskey(d, k) ? d[k] : (d[k] = $(esc(default)))
    end
end

end # module
