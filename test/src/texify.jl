module TestTexify

using Test, IESopt

function _test_texify()
    @test IESopt._int2timeidx(5) == "{t+5}"
    @test IESopt._int2timeidx(-1) == "{t-1}"
    @test IESopt._int2timeidx(0) == "t"

    @test IESopt._escape_variable("parent.var[5]", 3) == "\\vb{parent}_{\\vb{var}_{t+2}}"
    @test IESopt._escape_variable("parent.var[5]", 3; fixed_t=true) == "\\vb{parent}_{\\vb{var}_5}"

    # This is due to floating point representation
    @test IESopt._expr_tostring([("x_1", -1.0), ("x_2", -1.005), ("y", "α")]; digits=2) ==
          "{-~x_1} - {1.0\\cdot x_2} + {α\\cdot y} "
    @test IESopt._expr_tostring([("x_1", 1.0), ("x_2", -10.005), ("y", "α")]; digits=2) ==
          "{x_1} - {10.01\\cdot x_2} + {α\\cdot y} "
    @test IESopt._expr_tostring([("\\beta", -1.4), ("x_2", -1.005), ("y", "\\alpha")]; digits=2) ==
          "{-~1.4\\cdot \\beta} - {1.0\\cdot x_2} + {\\alpha\\cdot y} "

    return nothing
end

"""
    runtests()

Runs all tests that are properly defined here (starting with "_test_")), suppressing `stdout` and `stderr`.
"""
function runtests()
    for name in names(@__MODULE__; all=true)
        if startswith("$(name)", "_test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

end # TestTexify

TestTexify.runtests()
