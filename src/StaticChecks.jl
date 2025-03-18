module StaticChecks

#=
    This is a translation of StaticLint.jl checks using JuliaSyntax instead of
    CSTParser. For the moment, it closely follows the StaticLint implementation.
    It is highly inefficient.
=#

export run_checks, run_check_nothing_comparison, run_check_const_if_cond,
       run_check_lazy, run_check_break_continue, run_check_const_local,
       run_check_use_of_literal,
       open_and_parse

# import JuliaSyntax

# TODO: Get rid of this?
const default_options = (true, true, true, true, true, true, true, true, true, true)

# TODO: Change this.
struct LintOptions
    call::Bool
    iter::Bool
    nothingcomp::Bool
    constif::Bool
    lazy::Bool
    datadecl::Bool
    typeparam::Bool
    modname::Bool
    pirates::Bool
    useoffuncargs::Bool
end
LintOptions() = LintOptions(default_options...)
LintOptions(::Colon) = LintOptions(fill(true, length(default_options))...)

LintOptions(options::Vararg{Union{Bool,Nothing},length(default_options)}) =
    LintOptions(something.(options, default_options)...)

# TODO: Get rid of this.
@enum(
    LintCodes,

    MissingRef,
    IncorrectCallArgs,
    IncorrectIterSpec,
    NothingEquality,
    NothingNotEq,
    ConstIfCondition,
    EqInIfConditional,
    PointlessOR,
    PointlessAND,
    UnusedBinding,
    InvalidTypeDeclaration,
    UnusedTypeParameter,
    IncludeLoop,
    MissingFile,
    InvalidModuleName,
    TypePiracy,
    UnusedFunctionArgument,
    CannotDeclareConst,
    InvalidRedefofConst,
    NotEqDef,
    KwDefaultMismatch,
    InappropriateUseOfLiteral,
    ShouldBeInALoop,
    TypeDeclOnGlobalVariable,
    UnsupportedConstLocalVariable,
    UnassignedKeywordArgument,
    CannotDefineFuncAlreadyHasValue,
    DuplicateFuncArgName,
    IncludePathContainsNULL,
    IndexFromLength,
    FileTooBig,
    FileNotAvailable,
)

const LintCodeDescriptions = Dict{LintCodes,String}(
    IncorrectCallArgs => "Possible method call error.",
    IncorrectIterSpec => "A loop iterator has been used that will likely error.",
    NothingEquality => "Compare against `nothing` using `isnothing` or `===`",
    NothingNotEq => "Compare against `nothing` using `!isnothing` or `!==`",
    ConstIfCondition => "A boolean literal has been used as the conditional of an if statement - it will either always or never run.",
    EqInIfConditional => "Unbracketed assignment in if conditional statements is not allowed, did you mean to use ==?",
    PointlessOR => "The first argument of a `||` call is a boolean literal.",
    PointlessAND => "The first argument of a `&&` call is a boolean literal.",
    UnusedBinding => "Variable has been assigned but not used.",
    InvalidTypeDeclaration => "A non-DataType has been used in a type declaration statement.",
    UnusedTypeParameter => "A DataType parameter has been specified but not used.",
    IncludeLoop => "Loop detected, this file has already been included.",
    MissingFile => "The included file can not be found.",
    InvalidModuleName => "Module name matches that of its parent.",
    TypePiracy => "An imported function has been extended without using module defined typed arguments.",
    UnusedFunctionArgument => "An argument is included in a function signature but not used within its body.",
    CannotDeclareConst => "Cannot declare constant; it already has a value.",
    InvalidRedefofConst => "Invalid redefinition of constant.",
    NotEqDef => "`!=` is defined as `const != = !(==)` and should not be overloaded. Overload `==` instead.",
    KwDefaultMismatch => "The default value provided does not match the specified argument type.",
    InappropriateUseOfLiteral => "You really shouldn't be using a literal value here.",
    ShouldBeInALoop => "`break` or `continue` used outside loop.",
    TypeDeclOnGlobalVariable => "Type declarations on global variables are not yet supported.",
    UnsupportedConstLocalVariable => "Unsupported `const` declaration on local variable.",
    UnassignedKeywordArgument => "Keyword argument not assigned.",
    CannotDefineFuncAlreadyHasValue => "Cannot define function ; it already has a value.",
    DuplicateFuncArgName => "Function argument name not unique.",
    IncludePathContainsNULL => "Cannot include file, path contains NULL characters.",
    IndexFromLength => "Indexing with indices obtained from `length`, `size` etc is discouraged. Use `eachindex` or `axes` instead.",
    FileTooBig => "File too big, not following include.",
    FileNotAvailable => "File not available."
)


using JuliaSyntax: JuliaSyntax

include("utils.jl")
include("checks.jl")


# TODO: `run_checks` should be split. It is called when running individual checks,
#       which is terrible.
function run_checks(x::JuliaSyntax.SyntaxNode, opts::LintOptions; individual_checks=true, propagate=true, kwargs...)
    check_all(x, opts)

    if !individual_checks
        return nothing
    end

    pass = true

    opts.nothingcomp && (run_check_nothing_comparison(x; propagate, kwargs...) || (pass = false))
    opts.constif && (run_check_const_if_cond(x; propagate, kwargs...) || (pass = false))
    opts.lazy && (run_check_lazy(x; propagate, kwargs...) || (pass = false))
    run_check_use_of_literal(x; propagate, kwargs...) || (pass = false)
    run_check_break_continue(x; propagate, kwargs...) || (pass = false)
    run_check_const_local(x; propagate, kwargs...) || (pass = false)

    return pass
end
function run_checks(x::JuliaSyntax.SyntaxNode, opts::AbstractVector{Symbol}; kwargs...)
    lint_opts = LintOptions(
        :call in opts,
        :iter in opts,
        :nothingcomp in opts,
        :constif in opts,
        :lazy in opts,
        :datadecl in opts,
        :typeparam in opts,
        :modname in opts,
        :pirates in opts,
        :useoffuncargs in opts
    )
    run_checks(x, lint_opts; kwargs...)
end
run_checks(x::JuliaSyntax.SyntaxNode; opts::Symbol=:all, kwargs...) =
    opts === :all ? run_checks(x, _IMPLEMENTED; kwargs...) : run_checks(x, [opts]; kwargs...)
# TODO: Different functions instead of methods? Or keep these methods and remove
#       some of the methods above? The above are mostly for keeping close to
#       StaticLint.
run_checks(filename::AbstractString, opts::AbstractVector{Symbol}; kwargs...) = run_checks(open_and_parse(filename), opts; kwargs...)
run_checks(filename::AbstractString; opts::Symbol=:all, kwargs...) = run_checks(open_and_parse(filename); opts, kwargs...)


# Individual checks

function run_check_nothing_comparison(x::JuliaSyntax.SyntaxNode; annotated=true, propagate=false, print=true)
    if !annotated
        run_checks(x; opts=:nothingcomp, individual_checks=false)
    end

    val = x.data.val
    # TODO: extract in function?
    err = isa(val, AbstractArray) ? val[1] : val
    if propagate && err !== StaticChecks.NothingEquality && err !== StaticChecks.ConstIfCondition
        propagate_check(x, run_check_nothing_comparison; propagate=true)
    end

    # @info "Checking for `nothing` comparison" x err

    ret = err === StaticChecks.NothingEquality || err === StaticChecks.NothingNotEq
    if ret && print
        signal_error(err, x)
    end

    return ret
end

function run_check_const_if_cond(x::JuliaSyntax.SyntaxNode; annotated=true, propagate=false, print=true)
    if !annotated
        run_checks(x; opts=:constif, individual_checks=false)
    end

    if isnothing(x.children) || isempty(x.children)
        return false
    end

    val = x.children[1].data.val
    err = isa(val, AbstractArray) ? val[1] : val

    if propagate && err !== StaticChecks.ConstIfCondition
        propagate_check(x, run_check_const_if_cond; propagate=true)
    end

    # @info "Checking for constant in `if` condition" x err propagate

    ret = err === StaticChecks.ConstIfCondition
    if ret && print
        signal_error(err, x.children[1])
    end

    return ret
end

function run_check_lazy(x::JuliaSyntax.SyntaxNode; annotated=true, propagate=false, print=true)
    if !annotated
        run_checks(x; opts=:lazy, individual_checks=false)
    end

    val = x.data.val
    err = isa(val, AbstractArray) ? val[1] : val

    if propagate && err !== StaticChecks.PointlessOR && err !== StaticChecks.PointlessAND
        propagate_check(x, run_check_lazy; propagate=true, print=print)
    end

    # @info "Checking for pointless && or ||" x err

    ret = err === StaticChecks.PointlessOR || err === StaticChecks.PointlessAND
    if ret && print
        signal_error(err, x)
    end

    return ret
end

function run_check_break_continue(x::JuliaSyntax.SyntaxNode; annotated=true, propagate=false, print=true)
    if !annotated
        run_checks(x; opts=:breakcontinue, individual_checks=false)
    end

    val = x.data.val
    err = isa(val, AbstractArray) ? val[1] : val

    if propagate && err !== StaticChecks.ShouldBeInALoop
        propagate_check(x, run_check_break_continue; propagate=true, print=print)
    end

    # @info "Checking for `break` or `continue` outside loop" x err

    ret = err === StaticChecks.ShouldBeInALoop
    if ret && print
        signal_error(err, x)
    end

    return ret
end

function run_check_const_local(x::JuliaSyntax.SyntaxNode; annotated=true, propagate=false, print=true)
    if !annotated
        run_checks(x; opts=:constlocal, individual_checks=false)
    end

    val = x.data.val
    err = isa(val, AbstractArray) ? val[1] : val

    if propagate && err !== StaticChecks.UnsupportedConstLocalVariable
        propagate_check(x, run_check_const_local; propagate=true, print=print)
    end

    # @info "Checking for `const local`" x err

    ret = err === StaticChecks.UnsupportedConstLocalVariable
    if ret && print
        signal_error(err, x)
    end

    return ret
end

function run_check_use_of_literal(x::JuliaSyntax.SyntaxNode; annotated=true, propagate=false, print=true)
    if !annotated
        run_checks(x; opts=:constlocal, individual_checks=false)
    end

    node =
        if defines_module(x)    ||
           defines_abstract(x)  ||
           defines_primitive(x) ||
           defines_struct(x)    ||
           is_assignment(x)
            x.children[1]
        elseif is_declaration(x)
            x.children[2]
        elseif is_binary_call(x)
            x.children[3]
        else
            x.data.val
        end
    val = node.data.val
    err = isa(val, AbstractArray) ? val[1] : val

    if propagate && err !== StaticChecks.InappropriateUseOfLiteral
        propagate_check(x, run_check_use_of_literal; propagate=true, print=print)
    end

    ret = err === StaticChecks.InappropriateUseOfLiteral
    if ret && print
        signal_error(err, node)
    end

    return ret
end

end # module StaticChecks
