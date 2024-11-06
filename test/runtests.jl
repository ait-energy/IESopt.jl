using Test, TestItemRunner, Suppressor
import Aqua, JET
import JuMP, HiGHS
using IESopt

const PATH_TESTFILES = normpath(@__DIR__, "test_files")
const PATH_CURRENT = pwd()

@testset "IESopt.jl" verbose = true begin
    @testset "Code quality" verbose = true begin
        @testset "Aqua.jl" verbose = true begin
            include("src/aqua.jl")
        end

        @testset "JET.jl" begin
            JET.test_package(IESopt; target_modules=(IESopt,))
        end
    end

    @run_package_tests verbose = true filter = ti -> (:general in ti.tags)
    @run_package_tests verbose = true filter = ti -> (:unittest in ti.tags)
    @testset "Basic (IESopt.jl)" verbose = true begin
        include("src/basic.jl")
    end

    @run_package_tests verbose = true filter = ti -> (:examples in ti.tags)
end
