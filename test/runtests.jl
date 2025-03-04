using Test
using StaticChecks, JuliaSyntax

@testset "Nothing comparison" begin
    expr = "a == nothing"
    @test run_check_nothing_comparison(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "nothing != (2 + 3)"
    @test run_check_nothing_comparison(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "nothing !== true"
    @test !run_check_nothing_comparison(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)
end

@testset "Const if condition" begin
    expr = "if true 1 end"
    @test run_check_const_if_cond(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "if true == true 1 end"
    @test !run_check_const_if_cond(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)
end

@testset "Pointless && or ||" begin
    expr = "x && false"
    @test run_check_lazy(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "true || x"
    @test run_check_lazy(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "x && y"
    @test !run_check_lazy(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)
end

@testset "`break` or `continue` outside loop" begin
    expr = "break"
    @test run_check_break_continue(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "continue"
    @test run_check_break_continue(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)
end

@testset "Local constant definition" begin
    expr = "const local x = 2"
    @test run_check_const_local(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "local x = 2"
    @test !run_check_const_local(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)

    expr = "const x = 2"
    @test !run_check_const_local(JuliaSyntax.parsestmt(JuliaSyntax.SyntaxNode, expr); annotated=false, print=false)
end
