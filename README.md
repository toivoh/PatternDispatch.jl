PatternDispatch.jl v0.0
=======================
Toivo Henningsson

This package is an attempt to provide method dispatch based on pattern matching for [Julia](julialang.org).
Bug reports and feature suggestions are welcome at
https://github.com/toivoh/PatternDispatch.jl/issues.

Installation
------------
In Julia, install the `PatternDispatch` package:

    Pkg.add("PatternDispatch")

Examples
--------
Pattern methods are defined using the `@pattern` macro. The method with the most specific pattern that matches the given arguments is invoked, 
with matching values assigned to the corresponding variables.
The pattern method that is invoked is guaranted to be no less specific than
any other pattern method that matches. 
Beyond that, no guarantees are made whatsoever about which method is invoked,
i.e. in the face of ambiguity, any of the most specific methods may be picked
at any given invocation.

Method signatures in pattern methods may contain variable names and/or
type assertions, just like regular method signatures.
(Varargs, e.g. `f(x,ys...)` are not implemented yet.)
A number of additional constructs are also allowed.
Signatures can contain a mixture of variables and literals, e.g.

    using PatternDispatch

    @pattern f(x) =  x
    @pattern f(2) = 42

    println({f(x) for x=1:4})

prints

    {1, 42, 3, 4}

Using `show_dispatch(f)` to inspect the generated dispatch code gives

    const f = (args...)->dispatch(args...)

    # ---- Pattern methods: ----
    # f(x,)
    function match1(x)	#  test_examples.jl, line 6:
        x
    end

    # f(2,)
    function match2()	#  test_examples.jl, line 7:
        42
    end

    # ---- Dispatch methods: ----
    function dispatch(x_1::Any)
        match1(x_1)
    end

    function dispatch(x_1::Int64)
        if is(x_1, 2)
            match2()
        else
            match1(x_1)
        end
    end

A type tuple is allowed as a second argument to `show_dispatch` to restrict
the set of dispatch methods printed,
e.g. `show_dispatch(f, (Int,))` prints only the second method, since the first 
one can never be triggered with an argument of type `Int`.

Signatures can also contain patterns of tuples and vectors:

    @pattern f2((x,y::Int)) = x*y
    @pattern f2([x,y::Int]) = x/y
    @pattern f2(x)          = nothing

    ==> f2((2,5)) = 10
        f2((4,3)) = 12
        f2([4,3]) = 1.3333333333333333
        f2((4,'a')) = f2({4,'a'}) = f2(1) = f2("hello") = f2((1,)) = f2((1,2,3)) = nothing

A vector pattern will match any `Vector`. To restrict to a given
element type, use e.g.

    @pattern f([x,y]::Vector{Int}) = ...

The pattern `p~q` matches a value if and only if 
it matches both patterns `p` and `q`.
This can be used e.g. to get at the actual vector that matched a vector pattern:

    @pattern f3(v~[x::Int, y::Int]) = {v,x*y}

    ==> f3([3,2])   = {[3, 2], 6}
        f3({3,2})   = {{3, 2}, 6}
        f3([3,2.0]) = nothing

Symbols in signatures are replaced by pattern variables by default
(symbols in the position of function names and at the right hand side of `::`
are not). To use the _value_ of a variabe at the point of method definition,
it can be interpolated into the method signature:

    @pattern f4($nothing) = 1
    @pattern f4(x)        = 2

    ==> f4(nothing) = 1
        f4(1) = f4(:x) = f4("hello") = 2

A warning is printed if a new definition makes dispatch ambiguous:

    @pattern ambiguous((x,y),z) = 2
    @pattern ambiguous(x,(1,z)) = 3

prints

    Warning: New @pattern method ambiguous(x_A, (1, z_A))
             is ambiguous with   ambiguous((x_B, y_B), z_B).
             Make sure ambiguous(x_A~(x_B, y_B), z_B~(1, z_A)) is defined first.

Features
--------
 * Pattern signatures can contain
   * variables, literals, and type annotations
   * unifications and tuples of patterns
 * Dispatch on most specific pattern
 * Generates dispatch code to find the most specific match for given arguments,
   in the form of nested `if` statements 
 * Leverages Julia's multiple dispatch to perform the initial steps of
   dispatch
 * Warning when addition of a pattern method causes dispatch ambiguity
 * Function to print generated dispatch code for a pattern function

Aim
---
 * Provide a powerful and intuitive dispatch mechanism based on pattern 
   matching
 * Support a superset of Julia's multiple dispatch
 * Generate fast matching code for a given collection of pattern method 
   signatures
 * Allow Julia's optimizations such as type inference to work with pattern
   dispatch

Planned/Possible Features
-------------------------
 * Patterns for arrays and dicts
 * varargs, e.g. `(x,ys...)`, `{x,ys...}` etc.
 * Support for non-tree patterns, where the same variable occurs in several positions
 * User definable pattern matching on user defined types
 * Greater expressiveness: more kinds of patterns...

Limitations
-----------
 * Not yet terribly tested
 * No support for type parameters a la f{T}(...)

Working Principles
==================
Semantics:
 * Pattern matching is conceptually performed on the arguments
   tuple of a function call, e.g. `(1,2,3)` in the call `f(1,2,3)`.
 * Equality of values is defined in terms of `is`,
   e.g. `@pattern f(3) = 5` matches on `f(x)` only if `is(x,3)`.

Background:
 * To be able to match a single pattern against a value, 
   the pattern has to provide
   * a _predicate_ to check whether a given value matches,
   * a set of _pattern variable_ symbols,
   * a _mapping_ of input values to pattern variable values, valid for matching patterns.
 * To do most-specific pattern dispatch, patterns must also support
   * a _partial order_ `p >= q`, 
     read as "p is less specific or equal to q", or
     "x matches q ==> x matches p, for any value x"
   * an _intersection_ operation `p & q`; 
     the pattern `p & q` will match those values that match both `p` and `q`.

Implementation aspects:
 * Patterns are represented by
   the operations needed to evaluate the matching predicate
   and the mapping, in the form of a 
   [DAG](http://en.wikipedia.org/wiki/Directed_acyclic_graph).
   * Each _node_ is either
     * an _operation_, such as to evaluate `isa(x,Int)` or `x[3]`,
       where `x` is the result value of another node, or
     * a _source_, such as a literal value or the pattern's input value.
   * Two nodes are equal iff they represent the same (sub-)DAG.
 * A pattern is composed of
   * a set of _guard predicates_ (boolean-valued nodes),
     such that the pattern matches iff all predicates evaluate to true,
   * a set of _bindings_ from symbols to nodes, to produce the mapping.
 * Two patterns are equal iff their guard sets are equal.
 * Pattern intersection `p & q` forms the union of the guards sets
   of `p` and `q`. The result is simplified, e.g.
   `x::Number & ::Int` reduces to `x::Int`.
 * `p >= q` is evaluated as `(p & q) == q`.
