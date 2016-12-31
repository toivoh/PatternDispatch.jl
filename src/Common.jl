module Common
export Head, headof, keyof, meet
export emit!, calc!, branch!, finish!
export reemit!

abstract Head


headof(node) = error("Unsupported node type $node")

keyof(head::Head) = head
meet(h1::Head, h2::Head) = (@assert h1 === h2; h1)


emit!(sink::Union{}, op::Head, args...) = nothing
calc!(sink::Union{}, op::Head, args...) = nothing
branch!(sink::Union{}) = nothing
finish!(sink)       = nothing # finish! defaults to doing nothing

reemit!(sink, source::Union{}) = nothing


end # module
