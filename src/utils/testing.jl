# Setup snippets, etc. for testing.
@testsnippet Dependencies begin
    import IESopt.Assets
    import IESopt.JuMP
end

@testmodule TestExampleModule begin
    using IESopt, Test
    import IESopt.Assets, IESopt.JuMP
    using Suppressor

    function check(cfg_name=nothing; obj, kwargs...)
        if isnothing(cfg_name)
            testset = Test.get_testset().description
            filename = occursin(":", testset) ? split(testset, ":")[2] : testset
        else
            filename = cfg_name
        end

        @info "TestExampleModule" mode = "run" file = filename raw = cfg_name

        m = generate!(String(Assets.get_path("examples", "$filename.iesopt.yaml")); kwargs...)
        optimize!(m)
        @test JuMP.objective_value(m) ≈ obj atol = 0.1
        safe_close_filelogger(m)
        return m
    end

    function run(cfg_name=nothing; kwargs...)
        if isnothing(cfg_name)
            testset = Test.get_testset().description
            filename = occursin(":", testset) ? split(testset, ":")[2] : testset
        else
            filename = cfg_name
        end

        @info "TestExampleModule" mode = "run" file = filename raw = cfg_name

        m = generate!(String(Assets.get_path("examples", "$filename.iesopt.yaml")); kwargs...)
        optimize!(m)
        safe_close_filelogger(m)
        return m
    end
end

@testitem "docstrings" tags = [:general] begin
    public_wo_docstr = filter(f -> Base.isexported(IESopt, f) && !Base.hasdoc(IESopt, f), names(IESopt))

    if !isempty(public_wo_docstr)
        println("Missing docstrings for:\n")
        println(join(string.(public_wo_docstr), "\n"))
    end

    @test isempty(public_wo_docstr)
end
