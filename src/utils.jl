using JuliaSyntax
using JuliaLowering

function open_and_parse(filename)::JuliaSyntax.SyntaxNode
    tree = open(filename, "r") do io
        JuliaSyntax.parse!(JuliaSyntax.SyntaxNode, io)
    end

    return tree[1]
end


## Checks utils ##

# TODO: Get rid of this.
const IMPLEMENTED = LintOptions(
    false,  # call
    false,  # iter
    true,   # nothingcomp
    true,   # constif
    true,   # lazy
    false,  # datadecl
    false,  # typeparam
    false,  # modname
    false,  # pirates
    false   # useoffuncargs
)

const _IMPLEMENTED = [
    :nothingcomp,
    :constif,
    :lazy,
    :breakcontinue,
    :constlocal
]

function propagate_check(x, check::Function, args...; kwargs...)
    if !isnothing(x.children) && length(x.children) > 0
        for i in 1:length(x.children)
            check(x.children[i], args...; kwargs...)
        end
    end
end

function set_error!(x::JuliaSyntax.SyntaxNode, err)
    x.data = isnothing(x.val) ?
        JuliaSyntax.SyntaxData(x.data.source, x.data.raw, x.data.position, err) :
        JuliaSyntax.SyntaxData(x.data.source, x.data.raw, x.data.position, [err, x.val])
end
has_error(x::JuliaSyntax.SyntaxNode) =
    x.val isa StaticChecks.LintCodes || (x.val isa AbstractVector && x.val[2] isa StaticChecks.LintCodes)
error_of(x::JuliaSyntax.SyntaxNode) = has_error(x) ? (x.val isa AbstractVector ? x.val[2] : x.val) : nothing

function signal_error(err::StaticChecks.LintCodes, expr::JuliaSyntax.SyntaxNode)
    (line, col) = JuliaSyntax.source_location(expr)
    @error "$(err) at line $(line), column $(col)\n$(StaticChecks.LintCodeDescriptions[err])"
end


## Internal utils ##

parent_of(x::JuliaSyntax.SyntaxNode) = x.parent

# Terminals

is_bool_literal(x::JuliaSyntax.SyntaxNode) = JuliaSyntax.kind(x) === K"Bool"
defines_struct(x::JuliaSyntax.SyntaxNode) = JuliaSyntax.kind(x) === K"struct"
defines_abstract(x::JuliaSyntax.SyntaxNode) = JuliaSyntax.kind(x) === K"abstract"
defines_primitive(x::JuliaSyntax.SyntaxNode) = JuliaSyntax.kind(x) === K"primitive"
defines_module(x::JuliaSyntax.SyntaxNode) = JuliaSyntax.kind(x) === K"module"

# Expressions

is_operator(x::JuliaSyntax.SyntaxNode) =
    JuliaSyntax.is_operator(x) ||
    JuliaSyntax.is_syntactic_operator(x) ||
    JuliaSyntax.kind(x) === K"Identifier" # this is wrong, but I don't know how to go around this change: https://github.com/JuliaLang/JuliaSyntax.jl/commit/35dc3bcebf9a1fe291cdc3865cb0cf018df806a6
is_binary_call(x::JuliaSyntax.SyntaxNode) =
    JuliaSyntax.kind(x) === K"call" &&
    length(x.children) == 3 &&
    is_operator(x.children[2])
is_binary_call(x::JuliaSyntax.SyntaxNode, op::Symbol) =
    is_binary_call(x) && x.children[2].data.val == op
is_binary_syntax(x::JuliaSyntax.SyntaxNode) =
    !isnothing(x.children) &&
    length(x.children) == 2 &&
    JuliaSyntax.is_operator(JuliaSyntax.head(x))

is_kwarg(x::JuliaSyntax.SyntaxNode) = nothing

is_assignment(x::JuliaSyntax.SyntaxNode) = is_binary_syntax(x) && JuliaSyntax.kind(x) === K"="
is_declaration(x::JuliaSyntax.SyntaxNode) = is_binary_syntax(x) && JuliaSyntax.kind(x) === K"::"

is_in_fexpr(x::JuliaSyntax.SyntaxNode, f) =
    f(x) || (parent_of(x) isa JuliaSyntax.SyntaxNode && is_in_fexpr(parent_of(x), f))


## Internal individual checks utils ##

is_bad_literal(x::JuliaSyntax.SyntaxNode) =
    JuliaSyntax.is_literal(x)           &&
    (JuliaSyntax.kind(x) === K"String"  ||
     JuliaSyntax.kind(x) === K"Integer" ||
     JuliaSyntax.kind(x) === K"Float"   ||
     JuliaSyntax.kind(x) === K"char"    ||
     JuliaSyntax.kind(x) === K"Bool")
