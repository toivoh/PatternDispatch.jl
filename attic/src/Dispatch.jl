


# ---- Decision Tree ----------------------------------------------------------

abstract Action
type Decision{T<:Action}
    guards::Vector{Guard}
    action::T
end

type Branch <: Action
    pass::Decision
    fail::Decision
end

type Method <: Action
    args::Vector{Value}
    f::Function
end

code_pass(results::Dict{Node,Any}, a::Branch) = code_dispatch(results, a.pass)
code_fail(results::Dict{Node,Any}, a::Branch) = code_dispatch(results, a.fail)

function code_pass(results::Dict{Node,Any}, a::Method)
    expr(:call, a.f, {evaluate!(results, arg) for arg in a.args}...)
end
code_fail(::Dict{Node,Any}, ::Method) = :(error("no matching pattern found"))

function code_dispatch(results::Dict{Node,Any}, d::Decision)
    pred = quot(true)
    results_fail = copy(results)
    for g in d.guards
        ex = evaluate!(results, g)
        pred = pred == quot(true) ? ex : (:($pred && $ex))
    end
    if pred == quot(true)
        code_pass(results, d.action)
    else
        pass = code_pass(results,      d.action)
        fail = code_fail(results_fail, d.action)
        :( $ex ? $pass : $fail )
    end
end


# ---- MethodTable ------------------------------------------------------------

using Graph

type Sig
    p::Pattern
    gt::Set{Sig}
    lt::Set{Sig}

    Sig(sig::Pattern) = new(sig, Set{Sig}(), Set{Sig}())
end

type MethodTable
    top::Sig
    bottom::Sig
    sigs::Set{Sig}

    function MethodTable() 
        top, bottom = Sig(toppat), Sig(nullpat)
        add(top.gt, bottom)
        add(bottom.lt, top)
        new(top, bottom, Set{Sig}(top, bottom))
    end
end

for (below, above, higher_eq) in ((:gt, :lt, >=), (:lt, :gt, <=)=)
    below, above, visit! = quot(below), quot(above), symbol("visit_$(below)!")
    @eval function $visit!(seen::Set{Sig}, s::Sig, at::Sig)
        if has(seen, at); return; end
        add(seen, at)
        if $higher_eq(s.p, at.p)  # s >= at
            if $higher_eq(at.p, s.p); return; end  # s == at
            # s > at
            add(s.($below)), at)
            add(at.($above), s)
        else
            for below in at.($below); $visit!(seen, s, below); end
        end        
    end
end

function add(mt::MethodTable, p::Pattern)
    s = Sig(p)
    add(mt.signatures, s) # todo: what if it's already in the DAG?
    visit_gt!(Set{Sig}(), s, mt.top)
    visit_lt!(Set{Sig}(), s, mt.bottom)
    for above in s.lt;  del_each(above.gt, s.gt)  end
    for below in s.gt;  del_each(below.lt, s.lt)  end
end


# ---- Create Decision Tree ---------------------------------------------------

firstitem(iter) = next(iter, start(iter))[1]

function dtree(mt::MethodTable)
    dtree(mt.top, mt.signatures)
end


function visit_gt!(seen::Set{Sig}, s::Sig)
    if has(seen, s); return; end
    add(seen, s)
    for below in s.gt; visit_gt!(seen, below); end       
end

function dtree(top::Sig, sigs::Set{Sig})
    pivot = firstitem(top.gt) # should always have at least the bottom below
    if pivot.p === nullpat
        # todo: fill in guards
        # todo: fill method
        Decision(Guard[], Method(Value[], ()->()))
    else
        below = Set{Sig}()
        visit_gt!(below, pivot)
        pass = dtree(pivot, sigs & below)
        fail = dtree(top,   sigs - below)
        # todo: fill in guards
        Decision(Guard[], Branch(pass, fail))
    end    
end
