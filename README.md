# StaticChecks.jl

This is the beginning of translating [`StaticLint.jl` checks](https://github.com/julia-vscode/StaticLint.jl/blob/master/src/linting/checks.jl)
from a [`CSTParser.jl`](https://github.com/julia-vscode/CSTParser.jl) API to
a [`JuliaSyntax.jl`](https://github.com/JuliaLang/JuliaSyntax.jl/tree/main) API.


## Usage

You can run all implemented checks at once to test a file:

```julia
julia> run_checks("test/testfile.jl")
┌ Error: NothingEquality at line 1, column 1
│ Compare against `nothing` using `isnothing` or `===`
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: ConstIfCondition at line 3, column 4
│ A boolean literal has been used as the conditional of an if statement - it will either always or never run.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: ConstIfCondition at line 16, column 16
│ A boolean literal has been used as the conditional of an if statement - it will either always or never run.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: PointlessOR at line 5, column 3
│ The first argument of a `||` call is a boolean literal.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: ShouldBeInALoop at line 7, column 1
│ `break` or `continue` used outside loop.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: ShouldBeInALoop at line 28, column 5
│ `break` or `continue` used outside loop.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: UnsupportedConstLocalVariable at line 9, column 1
│ Unsupported `const` declaration on local variable.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
┌ Error: UnsupportedConstLocalVariable at line 24, column 9
│ Unsupported `const` declaration on local variable.
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:54
false
```

You can also run the checks on a [`SyntaxNode`](https://julialang.github.io/JuliaSyntax.jl/dev/api/#JuliaSyntax.SyntaxNode).
Running on a `SyntaxNode` is possible for individual checks as well:

```julia
julia> run_check_nothing_comparison(open_and_parse("test/testfile.jl"); annotated=false, propagate=true, print=true)
┌ Error: NothingEquality at line 1, column 1
│ Compare against `nothing` using `isnothing` or `===`
└ @ StaticChecks ~/.../StaticChecks.jl/src/utils.jl:55
false
```

Note that you need to add the `annotated=false` flag. It is set to `true` by default
in order to not run all the checks each time a specific check is run. This is caused
by a bad design choice.


## Notes

- The result is currently being printed to standard output by propagating a `print`
flag. This will be changed such that the result is given as a `Dict` or another
relevant struct.

- Only a small list of checks is currently implemented, those for which `JuliaSyntax`
is sufficient. Most of the other checks implemented in `StaticLint` require scope
information.

- There needs to be a better API. The annoying `annotated`, `print` and `propagate`
flags need to disappear.

- There should be separation between `run_checks` and the individual check functions.
