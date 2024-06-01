using IESopt
using Test
using Aqua
using JET

@testset "IESopt.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(IESopt)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(IESopt; target_defined_modules = true)
    end
    # Write your tests here.
end
