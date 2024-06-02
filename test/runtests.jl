using IESopt, Suppressor
using Test, Aqua, JET
import JuMP

@testset "IESopt.jl" verbose = true begin
    @testset "Code quality (Aqua.jl)" begin
        # Aqua.test_all(IESopt)
    end

    @testset "Code linting (JET.jl)" begin
        JET.test_package(IESopt; target_defined_modules = true)
    end

    @testset "Basic (IESopt.jl)" begin
        @test true
    end
end
