
module Meta
using Toivo
export subs_ex

function subs_ex(subs::Function, ex)
    s = subs(ex)
    s === nothing ? subsubs_ex(subs, ex) : s
end

subsubs_ex(subs::Function, ex) = ex
function subsubs_ex(subs::Function, ex::Expr)
    ex.head === :quote ? ex : expr(ex.head, {subs_ex(subs,a) for a in ex.args})
end

end