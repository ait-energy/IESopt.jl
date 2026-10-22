using TestItemRunner

@run_package_tests

@testsnippet TestFiles begin
    const PATH_TESTFILES = normpath(@__DIR__, "test_files")
    const PATH_CURRENT = pwd()
end

include("src/basic.jl")
include("src/examples.jl")
include("src/issues.jl")
include("src/texify.jl")

@testitem "Aqua" begin
    import Aqua
    Aqua.test_all(IESopt)
end
