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
(Among the matching pattern methods, any one that is no less specific than the others may be picked - this will be unique as long as you don't get any ambiguity warnings.)

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
    function match1(x) # test_examples.jl, line 6:
        x
    end
    
    # f(2,)
    function match2() # test_examples.jl, line 7:
        42
    end
    
    # ---- Dispatch method: ----
    function dispatch(args...)
        if isa(args,(Any,))
            x_1 = args[1]
            if (x_1===2)
                return match2()
            end
            return match1(x_1)
        end
        error("No matching pattern found for f")
    end

<!---
A type tuple is allowed as a second argument to `show_dispatch` to restrict
the set of dispatch methods printed,
e.g. `show_dispatch(f, (Int,))` prints only the second method, since the first 
one can never be triggered with an argument of type `Int`.
-->

Repeated variables require each occurence to be the same to match:

    @pattern egal(x, x) = true
    @pattern egal(x, y) = false

    ==> egal(1,1) = true
        egal(1,2) = egal(1,1.0) = egal(1,"foo") = false
        egal("foo","foo") = false
        (s = "foo"; egal(s,s)) = true

Here, `egal` will work just like the builtin `is` function. Note that equal-content strings are not generally egal.

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
    @pattern f3(v) = nothing

    ==> f3([3,2])   = {[3, 2], 6}
        f3({3,2})   = {{3, 2}, 6}
        f3([3,2.0]) = nothing

This also allows to create patterns that match circular data structures, e.g. a pattern that only matches a vector made up of itself:

    @pattern f4(v~[v]) = true
    @pattern f4([v])   = false

    ==> f4([1]) = f4([[1]]) = f4([[[1]]]) = false
        (v = {1}; v[1] = v; f4(v))        = true

Symbols in signatures are replaced by pattern variables by default
(symbols in the position of function names and at the right hand side of `::`
are not). To use the _value_ of a variabe at the point of method definition,
it can be interpolated into the method signature:

    @pattern f5($nothing) = 1
    @pattern f5(x)        = 2

    ==> f5(nothing) = 1
        f5(1) = f5(:x) = f5("hello") = 2

A warning is printed if a new definition makes dispatch ambiguous:

    @pattern ambiguous((x,y),z) = 2
    @pattern ambiguous(x,(1,z)) = 3

prints

    Warning: New @pattern method ambiguous(x_A, (1, z_A))
             is ambiguous with   ambiguous((x_B, y_B), z_B).
             Make sure ambiguous(x_A~(x_B, y_B), z_B~(1, z_A)) is defined first.

### Inverse functions ###

Besides the built-in patterns, user defined patterns can be specified in the form of inverse functions, including inverse constructors.
Inverse functions are allowed for functions with a pure, unique, and side-effect free inverse. Given

    type MyType
        x
        y
    end

we can define the inverse function through

    @pattern function (@inverse MyType(x, y))(mt)
        mt::MyType
        x = mt.x
        y = mt.y
    end

The body of the inverse function recieves the output of the original function (`mt` in this case) and must assign all of its inputs (`x` and `y` in this case).
Type type assertion `mt::MyType` works as a guard that the inverse exists only if `mt` is of type `MyType`. With these definitions,

    @pattern f6(MyType(x, y)) = (x,y)
    @pattern f6(x)            = nothing

    ==> f6(MyType(5,'x')) = (5,'x')
        f6(11)            = nothing

**Note:** By specifying an inverse function, you are interacting with the internals of the pattern matching machinery. In order not to invalidate the assumptions that it is based on, you must make sure that any inverse function defined satisfies certain properties. In particular, **all steps of the inverse calculation must** 

* be free of side effects, and
* return egal results when called twice with egal inputs and no side effects in between.

Inverse functions can be overloaded based on the number of arguments. 
If we add an additional (outer) constructor

    MyType(x) = MyType(x, x)

we should add the inverse to match:

    @pattern function (@inverse MyType(x))(mt)
        mt::MyType
        x = mt.x
        y = mt.y
        x ~ y
    end

This inverse will only exist for `mt::MytType` if `mt.x === mt.y`. The expression `x ~ y` guards that `x === y`, and returns the value.
With the two inverse constructors,

    @pattern f7(MyType(x))   = (1,x)
    @pattern f7(MyType(x,y)) = (2,x,y)

    ==> f7(MyType('a','a')) = (1,'a')
        f7(MyType('a','b')) = (2,'a','b')

Inverse functions can be defined also for non-constructors. 
The inverse of the function

    two_times_int(x::Int) = (@assert (typemin(Int)>>1) <= x <= (typemax(Int)>>1); 2x)

can be expressed as

    @pattern function (@inverse two_times_int(x))(y)
        y::Int
        @guard iseven(y)
        x = y >> 1
    end

where `@guard iseven(y)` guards that the inverse exists only if `iseven(y)` holds true.
Then

    @pattern f8(x::Int, y::Int)           = (x,y)
    @pattern f8(x::Int, two_times_int(x)) = x

    ==> f8(3,5) = (3,5)
        f8(3,6) = 3
        f8(4,8) = 4

Inverse functions can even be defined for some multivalued functions (which are not proper functions), when the inverse is unique. Let `odd` be the multivalued function that returns all odd integers. We cannot define this as a function, so we will have to be content with

    odd() = error() # conceptually returns all odd integers

The inverse function, however, can be defined as

    @pattern function (@inverse odd())(x)
        x::Integer
        @guard isodd(x)
    end

Then

    @pattern f9(odd(),     odd())     = "Both odd"
    @pattern f9(odd(),     ::Integer) = "One odd"
    @pattern f9(::Integer, odd())     = "One odd"
    @pattern f9(::Integer, ::Integer) = "Both even"

    ==> f9(3,5) = "Both odd"
        f9(3,6) = "One odd"
        f9(4,8) = "Both even"


Features
--------
 * Pattern signatures can contain
   * variables, literals, and type annotations
   * unifications and tuples of patterns
   * vector and inverse function patterns
 * Dispatch on most specific pattern
 * Generates dispatch code to find the most specific match for given arguments,
   in the form of nested `if` statements 
 * Warning when addition of a pattern method causes dispatch ambiguity
 * Function to print generated dispatch code for a pattern function

<!---
 * Leverages Julia's multiple dispatch to perform the initial steps of
   dispatch
-->

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
   e.g. `@pattern f(3) = 5` matches on `f(x)` only if `is(x,3)` (which can also be written as `x === 3`).

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
     * a _source_, such as a literal value or the pattern's input value, or
     * a _guard_, that defines necessary condition for the pattern to match
       * type guards (guard that `isa(x,T)` for some given type `T`)
       * egal guards (guard that `x === y`)
   * Two nodes are equal iff they represent the same (sub-)DAG.
 * A pattern is composed of
   * a set of guards,
     such that the pattern matches iff all guards are satisfied,
   * a set of _bindings_ from symbols to nodes, to produce the mapping.
 * Pattern intersection `p & q` forms the union of the guards sets
   of `p` and `q`. The result is simplified, e.g.
   `x::Number & ::Int` reduces to `x::Int`.
