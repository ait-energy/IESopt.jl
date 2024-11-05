using Test, TestItemRunner
import Aqua, JET
using IESopt
import JuMP, HiGHS, Suppressor

const PATH_EXAMPLES = IESopt.Assets.get_path("examples")
const PATH_TESTFILES = normpath(@__DIR__, "test_files")
const PATH_CURRENT = pwd()

@testset "IESopt.jl" verbose = true begin
    @testset "Code quality" begin
        @testset "Aqua.jl" begin
            include("src/aqua.jl")
        end

        @testset "JET.jl" begin
            JET.test_package(IESopt; target_modules = (IESopt,))
        end
    end

    @testset "Unit tests (IESopt.jl)" begin
        @run_package_tests filter = ti -> (:unittest in ti.tags)
    end

    @testset "Basic (IESopt.jl)" begin
        include("src/basic.jl")
    end

    @testset "Examples (IESopt.jl)" begin
        # include("src/examples.jl")
    end
end
