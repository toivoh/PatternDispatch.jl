module Common
export Head, headof, keyof, meet
export emit!, calc!, branch!, finish!
export reemit!

abstract Head


headof(node) = error("Unsupported node type $node")

keyof(head::Head) = head
meet(h1::Head, h2::Head) = (@assert h1 === h2; h1)


emit!(sink::None, op::Head, args...) = nothing
calc!(sink::None, op::Head, args...) = nothing
branch!(sink::None) = nothing
finish!(sink)       = nothing # finish! defaults to doing nothing

reemit!(sink, source::None) = nothing


end # module
