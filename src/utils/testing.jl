# Setup snippets, etc. for testing.
@testsnippet Dependencies begin
    import IESopt.Assets
    import IESopt.JuMP
end

@testmodule TestExampleModule begin
    using IESopt, Test
    import IESopt.Assets, IESopt.JuMP
    using Suppressor

    function check(cfg_name=nothing; obj, verbosity=false, kwargs...)
        if isnothing(cfg_name)
            testset = Test.get_testset().description
            filename = occursin(":", testset) ? split(testset, ":")[2] : testset
        else
            filename = cfg_name
        end
        m = @suppress generate!(Assets.get_path("examples", "$filename.iesopt.yaml"); verbosity=verbosity, kwargs...)
        @suppress optimize!(m)
        @test JuMP.objective_value(m) ≈ obj atol = 0.1
        @suppress save_close_filelogger(m)
        return m
    end

    function run(cfg_name=nothing; verbosity=false, kwargs...)
        if isnothing(cfg_name)
            testset = Test.get_testset().description
            filename = occursin(":", testset) ? split(testset, ":")[2] : testset
        else
            filename = cfg_name
        end
        m = @suppress generate!(Assets.get_path("examples", "$filename.iesopt.yaml"); verbosity=verbosity, kwargs...)
        @suppress optimize!(m)
        @suppress save_close_filelogger(m)
        return m
    end
end
