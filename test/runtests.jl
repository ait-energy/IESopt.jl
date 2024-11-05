import HiGHS
using IESopt, Suppressor
using Test, Aqua, JET
import JuMP

const PATH_EXAMPLES = IESopt.Assets.get_path("examples")
const PATH_TESTFILES = @path normpath(@__DIR__, "test_files")
const PATH_CURRENT = pwd()

@testset "IESopt.jl" verbose = true begin
    @testset "Code quality (Aqua.jl)" begin
        include("src/aqua.jl")
    end

    @testset "Code linting (JET.jl)" begin
        # JET.test_package(IESopt; target_defined_modules = true)
    end

    @testset "Unit tests (IESopt.jl)" begin
        include("src/unit_tests.jl")
    end

    @testset "Basic (IESopt.jl)" begin
        include("src/basic.jl")
    end

    @testset "Examples (IESopt.jl)" begin
        include("src/examples.jl")
    end
end
