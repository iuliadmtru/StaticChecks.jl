#=
    These are translations of (some of the) StaticLint.jl checks.
    https://github.com/julia-vscode/StaticLint.jl/blob/master/src/linting/checks.jl
=#



function check_all(x::JuliaSyntax.SyntaxNode, opts::LintOptions)
    # Do checks
    opts.nothingcomp && check_nothing_equality(x)
    opts.constif && check_if_conds(x)
    opts.lazy && check_lazy(x)
    check_use_of_literal(x)
    check_break_continue(x)
    check_const(x)
    # opts.call && check_call(x, env)
    # opts.iter && check_loop_iter(x, env)
    # opts.datadecl && check_datatype_decl(x, env)
    # opts.typeparam && check_typeparams(x)
    # opts.modname && check_modulename(x)
    # opts.pirates && check_for_pirates(x)
    # opts.useoffuncargs && check_farg_unused(x)
    # check_kw_default(x, env)

    propagate_check(x, check_all, opts)
end


function check_nothing_equality(x::JuliaSyntax.SyntaxNode)
    if is_binary_call(x)
        op = x.children[2].data.val
        if op === :(==) && (
            x.children[1].data.val === :nothing ||
            x.children[3].data.val === :nothing
            )
            set_error!(x, NothingEquality)
        elseif op === :(!=) && (
            x.children[1].data.val === :nothing ||
            x.children[3].data.val === :nothing
            )
            set_error!(x, NothingNotEq)
        end
    end
end

function check_if_conds(x::JuliaSyntax.SyntaxNode)
    if JuliaSyntax.kind(x) === K"if" || JuliaSyntax.kind(x) === K"elseif"
        cond = x.children[1]
        if is_bool_literal(cond)
            set_error!(cond, ConstIfCondition)  # should this be set in the condition?
        # elseif isassignment(cond)
        #     set_error!(cond, EqInIfConditional)  # is this intended?
        end
    end
end

function check_lazy(x::JuliaSyntax.SyntaxNode)
    if is_binary_syntax(x)
        if JuliaSyntax.kind(x) === K"||"
            if is_bool_literal(x.children[1])
                set_error!(x, PointlessOR)
            end
        elseif JuliaSyntax.kind(x) === K"&&"
            if is_bool_literal(x.children[1]) || is_bool_literal(x.children[2])
                set_error!(x, PointlessAND)
            end
        end
    end
end

function check_break_continue(x::JuliaSyntax.SyntaxNode)
    if JuliaSyntax.is_keyword(x) &&
       (JuliaSyntax.kind(x) === K"continue" || JuliaSyntax.kind(x) === K"break") &&
       !is_in_fexpr(x, x -> JuliaSyntax.kind(x) in (K"for", K"while"))
        set_error!(x, ShouldBeInALoop)
    end
end

function check_const(x::JuliaSyntax.SyntaxNode)
    if JuliaSyntax.kind(x) === K"const"
        if VERSION < v"1.8.0-DEV.1500" && is_assignment(x.args[1]) && is_declaration(x.children[1].children[1])
            set_error!(x, TypeDeclOnGlobalVariable)
        elseif JuliaSyntax.kind(x.children[1]) === K"local"
            set_error!(x, UnsupportedConstLocalVariable)
        end
    end
end

# These are all errors, is this check necessary?
function check_use_of_literal(x::JuliaSyntax.SyntaxNode)
    if defines_module(x) && length(x.args) > 1 && is_bad_literal(x.children[1]) # syntax error
        set_error!(x.children[1], InappropriateUseOfLiteral)
    elseif (defines_abstract(x) || defines_primitive(x)) && is_bad_literal(x.children[1]) # syntax error
        set_error!(x.children[1], InappropriateUseOfLiteral)
    elseif defines_struct(x) && is_bad_literal(x.children[1]) # syntax error
        set_error!(x.children[1], InappropriateUseOfLiteral)
    elseif is_assignment(x) && is_bad_literal(x.children[1]) # syntax error
        set_error!(x.children[1], InappropriateUseOfLiteral)
    elseif is_declaration(x) && is_bad_literal(x.children[2]) # `TypeError`
        set_error!(x.children[2], InappropriateUseOfLiteral)
    elseif is_binary_call(x, :isa) && is_bad_literal(x.children[3]) # `TypeError`
        set_error!(x.children[3], InappropriateUseOfLiteral)
    end
end

# function check_typeparams(x::JuliaSyntax.SyntaxNode)
#     # if iswhere(x)  -- why?
#     if JuliaSyntax.kind(x.children[1]) === K"where"

#         for i in 2:length(x.args)
#             a = x.args[i]
#             if hasbinding(a) && (bindingof(a).refs === nothing || length(bindingof(a).refs) < 2)
#                 seterror!(a, UnusedTypeParameter)
#             end
#         end
#     end
# end

# function check_modulename(x::JuliaSyntax.SyntaxNode)
#     # !! Needs scope information => JuliaLowering

#     # if defines_module(x) &&  # x is a module
#     #     scopeof(x) isa Scope && parentof(scopeof(x)) isa Scope && # it has a scope and a parent scope
#     #     CSTParser.defines_module(parentof(scopeof(x)).expr) && # the parent scope is a module
#     #     valof(CSTParser.get_name(x)) == valof(CSTParser.get_name(parentof(scopeof(x)).expr)) # their names match
#     #     seterror!(CSTParser.get_name(x), InvalidModuleName)
#     # end
# end
