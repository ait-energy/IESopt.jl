using IESopt, Suppressor
using Test, Aqua, JET
import JuMP

const PATH_TEST = IESopt._PATHS[:test]
const PATH_EXAMPLES = IESopt._PATHS[:examples]
const PATH_TESTFILES = normpath(PATH_TEST, "test_files")
const PATH_CURRENT = pwd()

@testset "IESopt.jl" verbose = true begin
    @testset "Code quality (Aqua.jl)" begin
        include("src/aqua.jl")
    end

    @testset "Code linting (JET.jl)" begin
        # JET.test_package(IESopt; target_defined_modules = true)
    end

    @testset "Basic (IESopt.jl)" begin
        include("src/basic.jl")
    end

    @testset "Examples (IESopt.jl)" begin
        if isnothing(IESopt.Library)
        else
            include("src/examples.jl")
        end
    end
end
