using TestItemRunner

@run_package_tests

@testmodule TestFiles begin
    export PATH_CURRENT
    export PATH_TESTFILES

    const PATH_TESTFILES = normpath(@__DIR__, "test_files")
    const PATH_CURRENT = pwd()

    function clean()
        GC.gc()
        for path in (normpath(PATH_TESTFILES, "out"), normpath(PATH_TESTFILES, "filesystem", "out"))
            try
                rm(path; force=true, recursive=true)
            catch
                @warn "Failed to cleanup output files after testing, left-overs might be present" path
            end
        end
    end
end

include("src/basic.jl")
include("src/examples.jl")
include("src/issues.jl")
include("src/texify.jl")

@testitem "Aqua" begin
    import Aqua
    Aqua.test_all(IESopt)
end
