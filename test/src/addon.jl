"""
This is a copy of the XOR addon module in ./assets/examples/files/31/XOR.jl
to test addon loading without a file that is not loaded in Main.
"""
@testmodule XOR begin
    using IESopt
    import JuMP

    initialize!(model::JuMP.Model, config::Dict) = haskey(config, "bigM")

    function construct_variables!(model::JuMP.Model, config::Dict)
        JuMP.@variable(model, exchange[t in get_T(model)], Bin)
        return true
    end

    function construct_constraints!(model::JuMP.Model, config::Dict)
        T = get_T(model)
        bigM = config["bigM"]
        buy_id = get_component(model, "buy_id")
        sell_id = get_component(model, "sell_id")
        exchange = model[:exchange]
        JuMP.@constraint(model, [t in T], buy_id.exp.value[t] <= exchange[t] * bigM)
        JuMP.@constraint(model, [t in T], sell_id.exp.value[t] <= (1.0 - exchange[t]) * bigM)
        return true
    end
end

@testitem "addon loading" setup=[XOR] begin
    import IESopt.Assets
    import JuMP

    config_file = String(Assets.get_path("examples", "31_exclusive_operation.iesopt.yaml"))

    # the testmodule XOR is not loaded in Main
    @test !isdefined(Main, :XOR)

    # pass a different addons path to the config to ensure we are not loading from file.
    # IESopt still finds the XOR module and uses it as addon
    model = IESopt.run(config_file, config=Dict("paths.addons" => "./addons/"))

    @test JuMP.objective_value(model) ≈ -10.0
    @test JuMP.value.(get_component(model, "buy_id").exp.value) == [1, 0, 1, 0]
    @test JuMP.value.(get_component(model, "sell_id").exp.value) == [0, 1, 0, 1]
end