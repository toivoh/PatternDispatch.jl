PatternDispatch.jl v0.2
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
(As long as there are no ambiguity warnings, there is always a unique most specific matching pattern. Otherwise, some matching pattern that is no less specific than the others will be picked.)

Method signatures in pattern methods can contain variable names and/or
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

The generated dispatch code can be insoected using `show_dispatch(f)`,
which gives

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

Repeated variables require each occurence to be the same (according to the `is` function) to match:

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

A vector pattern will match any `Vector` with the right elements.
To restrict the type of the Vector itself, use e.g.

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
are currently not). To use the _value_ of a variabe at the point of method definition,
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
The type assertion `mt::MyType` works as a guard that the inverse exists only if `mt` is of type `MyType`. With these definitions,

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

since the first method of `f7` is more specific than the second one (and should be equally specific as `f7(MyType(x,x))`).

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

Reference
---------

`PatternDispatch` allows to define

 * _Pattern functions_ - functions that choose the method to be invoked based on pattern matching instead of Julia's regular [multiple dispatch](http://docs.julialang.org/en/latest/manual/methods/#man-methods) mechanism. Pattern functions are made up of _pattern methods_.
 * _Inverse functions_ - which can be used in patterns.

Definitions of both pattern methods and inverse functions are wrapped with the `@pattern` macro, or multiple definitions can be wrapped in

    @patterns begin
        ...
    end
Pattern methods and regular methods cannot be mixed in the same function.

### Principles ###

Patterns are based on a notion of equality called _egal_, such that if `x` and `y` are egal then they are indistinguishable by Julia code. Egality can be tested in Julia by `is(x,y)`, or equivalently, `x===y`. 

When a pattern function is called, _dispatch_ is first invoked to decide which pattern method will be called (and to compute values for its arguments).
Dispatch, and all functions that participate in it, must be _momentarily pure_, i.e. **must**

 * be free of side effects, and
 * return egal results when called twice with egal inputs and no side effects in between.

Since (correct) dispatch relies on it, **the user must guarantee this property for any supplied inverse function definition;** it will then hold for all dispatch code. It allows to compare patterns by specificity and generate more efficient dispatch code.

### Patterns ###
When a pattern function is invoked, dispatch is conceptually carried out by trying to match all of its pattern methods agains the tuple of actual arguments, and choosing the most specific matching pattern. (In practice, many of the operations to test for matching will be shared between patterns.)
E.g., when trying to match the call `f(1, 2)` against the pattern method

    f(x::Int, 2) = x

dispatch will try to match the argument tuple `(1, 2)` against the pattern tuple `(x::Int, 2)`. This section describes how patterns are composed and the conditions for when they match.

Matching proceeds from argument tuple and inwards. Patterns can be built from the following elementary parts:

 * A **literal** value such as `2` or **interpolated value** such as `$nothing` matches a value `v` if the two values are egal.
 * A **pattern variable** such as `x` _binds_ the matched value `v` to `x`; if the variable has already been bound then it matches only if the new binding is egal to the previous one. 
 * A **pattern intersection** such as `p ~ q` matches a value `v` if both the patterns `p` and `q` match `v`.
 * A **type guard** such as `::T` matches a value `v` if it is an instance of the type `T`. A type guard on a pattern, such as `x::Int`, is short for `x ~ ::Int`.
 * A **tuple pattern** such as `(p, q)` matches a value `v` if it is a tuple with the right number of elements, and each element matches the corresponding pattern.
 * A **vector pattern** such as `[p, q]` matches a value `v` if it is a `Vector` with the right number of elements, and each element matches the corresponding pattern.
 * A **function pattern** such as `f(p, q)` matches a value `v` if the inverse function for `f` with the right number of arguments matches `v`, and its return value tuple matches the tuple pattern `(p, q)`.

If a pattern matches and its pattern method is invoked, the values bound to its pattern variables are used for its arguments.

### Inverse Functions ###

`PatternDispatch.jl` represents patterns by the operations needed to check whether a pattern matches (and if so, calculate its argument bindings).

Inverse functions allow to specify the operations to be used when trying to match a function pattern such as `f(x, y, z)`.
The result value of the function is supplied as input, and the inverse function should calculate values for each of the arguments, e.g. `(x, y, z)`. It can also use guards to signify conditions for when the inverse exists.

Since inverse functions are a form of user-defined patterns, the user must be well aware of the assumptions placed upon patterns before defining any; 
before describing how to define inverse functions we first consider these assumptions.

**Note:** Inverse functions are an experimental feature. They will remain in `PatternDispatch.jl`, but the exact syntax and semantics may still change.

#### Momentarily Pure Functions ####
Since they are used in dispatch,
only momentarily pure functions may be used in inverse function definitions.

Pure functions are a subset of momentarily pure functions.
A _pure_ function is one that

 * is free of side effects, and
 * returns egal results when called twice with egal inputs.

Additionally, a _momentarily pure_ function may return different results for egal inputs if there have been side effects in between.

Examples of momentarily pure functions include pure functions such as

    +(::Int, ::Int)
    tuple(args...)
    length(::Tuple)
    getindex(::Tuple, ::Int)

Examples of other momentarily pure functions (that are not pure) are

    length(::Vector)
    getindex(::Array, inds::Int...)

as well as field access, e.g. `obj->obj.x`.
Side effects may cause a `Vector` to change its length, or change the elements of an `Array`, but in between side effects, both `length` and `getindex` (for single elements) will act as if they were pure (and they don't have any side effects). 

We have restricted the argument types of `length` and `getindex` above, but by convention they should be momentarily pure for any type of the first argument.
We will soon see why `getindex` is not momentarily pure for general arguments.

Functions that are not momentarily pure include `setindex!` and `+(::Array, Array)`. `setindex!` clearly has a side effect. `+(::Array, Array)` will allocate a new result array each time, and thus will never give egal results even with egal inputs:

    julia> a,b = [1],[2]; a+b === a+b
    false

For the same reasone, methods of `getindex` that allocate a new array 
are never momentarily pure, and neither are mutable type constructors.
Construtors of immutable types can be pure, however.

We will consider a constructor that has no side effects beyond initializing the newly allocated object to be side effect free, which as we will see can allow us to define an inverse for it. (This implies that, e.g., a function that returns the number of bytes currently allocated on the heap will not be considered momentarily pure.)

#### Allowable Inverses ####

Consider a side effect free function `f`. We will consider a function `finv` to be the _inverse function_ of `f` if

 * for all tuples `args` such that `f(args...)` returns a result, 
            y = f(args...)
        ==> finv(y) === args
 * for all `y` such that there is no tuple `args` that yields the result `f(args...) === y`,
   `finv(y)` is **undefined.**
    
Note that the definition allows the inverse to be a _partial function_, i.e. a function that is undefined for some argument values (exaclty those for which the inverse does not exist). This will be captured by _guard conditions_ in the inverse function definition.

The inverse function may be defined for a function if the inverse is unique and momentarily pure. The function itself need not be momentarily pure; inverse constructors is one of the most useful kinds of inverse functions.

The inverse function must be kept consistent with the original function.
Ideally, they should be mainained together. For functions that will have several methods added to them in different places, it is typically prudent not to define an inverse function, since it will be very hard to derive and keep consistent.

#### Inverse function definitions ####
An inverse function definition specifieces, step by step, how determine whether the inverse matches a given result, and if so, its argument values.

...

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
