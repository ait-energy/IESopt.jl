@testset "Basic models" begin
    model = generate!(joinpath(PATH_TESTFILES, "increased_fuel.iesopt.yaml"))
    optimize!(model)
    @test JuMP.objective_value(model) ≈ 0 atol = 0.1

    model = generate!(joinpath(PATH_TESTFILES, "variable_unit_count.iesopt.yaml"))
    optimize!(model)
    @test JuMP.objective_value(model) ≈ 71000 atol = 0.1

    model = generate!(joinpath(PATH_TESTFILES, "availability_test_success.iesopt.yaml"))
    optimize!(model)
    @test JuMP.objective_value(model) ≈ 1000 atol = 0.1

    model = generate!(joinpath(PATH_TESTFILES, "availability_test_failure.iesopt.yaml"))
    @suppress optimize!(model)      # `@test_logs` fails because: https://github.com/JuliaLang/julia/issues/48456
    @test JuMP.termination_status(model) == JuMP.MOI.INFEASIBLE
end

@testset "Versioning" begin
    v_curr = VersionNumber(string(pkgversion(IESopt))::String)
    v_good = [v_curr, VersionNumber(v_curr.major)]
    v_bad = [@v_str("1"), VersionNumber(v_curr.major + 1), VersionNumber(v_curr.major, v_curr.minor, v_curr.patch + 1)]

    err_msg = "Error: The required `version.core`"

    fn = String(Assets.get_path("examples", "01_basic_single_node.iesopt.yaml"))

    for v in v_good
        @test !occursin(err_msg, @capture_err generate!(fn; config=Dict("general.version.core" => string(v))))
    end

    for v in v_bad
        @test occursin(err_msg, @capture_err generate!(fn; config=Dict("general.version.core" => string(v))))
    end
end

@testset "Filesystem paths" verbose = true begin
    for fn in (
        "include_components.iesopt.yaml",
        "include_components_slash.iesopt.yaml",
        "include_dotslash_components.iesopt.yaml",
        "include_dotslash_components_slash.iesopt.yaml",
        "include_components_slash_windows.iesopt.yaml",
        "include_dotslash_components_windows.iesopt.yaml",
        "include_dotslash_components_slash_windows.iesopt.yaml",
    )
        @testset "$(split(fn, ".")[1])" begin
            # full path
            model = JuMP.Model()
            IESopt.generate!(model, joinpath(PATH_TESTFILES, "filesystem", fn))
            @test haskey(model.ext[:_iesopt].input.noncore[:templates], "TestComp")
            IESopt.safe_close_filelogger(model)

            # relative path
            cd(PATH_TESTFILES)
            model = JuMP.Model()
            IESopt.generate!(model, joinpath("filesystem", fn))
            IESopt.safe_close_filelogger(model)

            # filename only
            @test haskey(model.ext[:_iesopt].input.noncore[:templates], "TestComp")
            cd(joinpath(PATH_TESTFILES, "filesystem"))
            model = JuMP.Model()
            IESopt.generate!(model, fn)
            @test haskey(model.ext[:_iesopt].input.noncore[:templates], "TestComp")
            cd(PATH_CURRENT)
            IESopt.safe_close_filelogger(model)
        end
    end
end

# Clean up output files after testing is done.
try
    rm(joinpath(PATH_TESTFILES, "out"); force=true, recursive=true)
    rm(joinpath(PATH_TESTFILES, "filesystem", "out"); force=true, recursive=true)
catch
end
