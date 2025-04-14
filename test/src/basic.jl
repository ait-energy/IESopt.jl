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

@testset "Connection (loss)" begin
    model = generate!(joinpath(PATH_TESTFILES, "connection_loss.iesopt.yaml"))
    optimize!(model)

    @test JuMP.value(get_component(model, "conn1").exp.in[1]) ≈ 10.0 atol = 0.01
    @test JuMP.value(get_component(model, "conn1").exp.out[1]) ≈ 10.0 atol = 0.01

    @test JuMP.value(get_component(model, "conn2").exp.in[1]) ≈ 10.0 atol = 0.01
    @test JuMP.value(get_component(model, "conn2").exp.out[1]) ≈ 9.0 atol = 0.01

    @test JuMP.value(get_component(model, "conn3").exp.in[1]) ≈ 10.0 / 0.9 atol = 0.01
    @test JuMP.value(get_component(model, "conn3").exp.out[1]) ≈ 10.0 atol = 0.01

    @test JuMP.value(get_component(model, "conn4").exp.in[1]) ≈ 10.0 / sqrt(0.9) atol = 0.01
    @test JuMP.value(get_component(model, "conn4").exp.out[1]) ≈ 10.0 * sqrt(0.9) atol = 0.01

    @test JuMP.value(get_component(model, "conn1").var.flow[1]) ≈ 10.0 atol = 0.01
    @test JuMP.value(get_component(model, "conn2").var.flow[1]) ≈ 10.0 atol = 0.01
    @test JuMP.value(get_component(model, "conn3").var.flow[1]) ≈ 10.0 atol = 0.01
    @test JuMP.value(get_component(model, "conn4").var.flow[1]) ≈ 10.0 atol = 0.01
end

@testset "Connection (delay)" begin
    model = generate!(joinpath(PATH_TESTFILES, "connection_delay.iesopt.yaml"))
    IESopt.optimize!(model)

    @test all(JuMP.value.(get_component(model, "conn1").exp.in) .≈ [1.0, 1.0, 1.0, 1.0])
    @test all(JuMP.value.(get_component(model, "conn1").exp.out) .≈ [1.0, 1.0, 1.0, 1.0])

    @test all(JuMP.value.(get_component(model, "conn2").exp.in) .≈ [1.0, 1.0, 0.0, 0.0])
    @test all(JuMP.value.(get_component(model, "conn2").exp.out) .≈ [0.0, 0.0, 0.9, 0.9])

    @test maximum(abs.(JuMP.value.(get_component(model, "conn3").exp.in) .- [1.111, 0.168, 1.111, 0.0])) <= 1e-3
    @test maximum(abs.(JuMP.value.(get_component(model, "conn3").exp.out) .- [0.0, 1.0, 0.151, 0.999])) <= 1e-3

    @test maximum(abs.(JuMP.value.(get_component(model, "conn4").exp.in) .- [0.0, 0.0, 1.054, 1.054])) <= 1e-3
    @test maximum(abs.(JuMP.value.(get_component(model, "conn4").exp.out) .- [0.0, 0.0, 0.948, 0.948])) <= 1e-3

    @test JuMP.objective_value(model) ≈ 10.4985 atol = 0.01
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
GC.gc()
try
    rm(normpath(PATH_TESTFILES, "out"); force=true, recursive=true)
catch
    @warn "Failed to cleanup output files after testing, left-overs might be present" path =
        normpath(PATH_TESTFILES, "out")
end
try
    rm(normpath(PATH_TESTFILES, "filesystem", "out"); force=true, recursive=true)
catch
    @warn "Failed to cleanup output files after testing, left-overs might be present" path =
        normpath(PATH_TESTFILES, "filesystem", "out")
end
