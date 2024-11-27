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

    model = generate!(joinpath(PATH_TESTFILES, "issue35.iesopt.yaml"))
    @test access(get_component(model, "electricity_demand").value) ≈ 7e-6
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
