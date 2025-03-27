# Run basic tests that check the objective value of the example against a prerecorded value.

@testitem "01_basic_single_node" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=525.0)
end

@testitem "02_advanced_single_node" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=1506.75)
end

@testitem "03_basic_two_nodes" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=1225.0)
end

@testitem "05_basic_two_nodes_1y" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=667437.8)
end

@testitem "06_recursion_h2" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=18790.8)
end

@testitem "07_csv_filestorage" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=667437.8)
end

@testitem "08_basic_investment" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=2015.6)
end

@testitem "09_csv_only" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=667437.8)
end

@testitem "10_basic_load_shedding" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=25000 + 1083.9)
end

@testitem "11_basic_unit_commitment" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=1570.0)
end

@testitem "12_incremental_efficiency" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=3570.0)
end

@testitem "15_varying_efficiency" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=2131435.8)
end

@testitem "16_noncore_components" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=4372.2)

    sp = JuMP.value.(get_component(model, "group").exp.setpoint)

    @test sum(sp) ≈ -0.25 atol = 0.01
    @test sum(abs.(sp)) ≈ 4.75 atol = 0.01
end

@testitem "17_varying_connection_capacity" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=300.0)
end

@testitem "18_addons" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=51.0)

    units = get_components(model; tagged=["ModifyMe"])
    @test all(JuMP.shadow_price.(units[1].con.example18) .≈ [-1, 0, 0, -1, -4])
    @test all(JuMP.shadow_price.(units[2].con.example18) .≈ [-2, 0, -1, -1, -5])
end

@testitem "25_global_parameters" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=50.0)
    TestExampleModule.check(; obj=100.0, parameters=Dict("demand" => 10))
end

@testitem "26_initial_states" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=150.0, parameters=Dict("store_initial_state" => 15))
    TestExampleModule.check(; obj=0.0, parameters=Dict("store_initial_state" => 50))
end

@testitem "27_piecewise_linear_costs" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=450.0)
end

@testitem "29_advanced_unit_commitment" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=7000.0)
end

# @testitem "30_representative_snapshots" tags = [:examples] setup = [TestExampleModule] begin
#     # TestExampleModule.check(; obj=319100.0)
#     model = TestExampleModule.run()
#     @test JuMP.objective_value(model) ≈ 319100.0 atol = 0.1 broken = true
#     # TODO: This is due to the Expression rework, that did not make use of aggregation in reading col@file values.
#     #       Re-implement, or remove if representative snapshots are re-implemented.
# end

@testitem "44_lossy_connections" tags = [:examples] setup = [TestExampleModule] begin
    TestExampleModule.check(; obj=1233.75)
end

# Run tests that manually check various outcomes of example models.

@testitem "04_soft_constraints" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.run()

    @test JuMP.value(model.ext[:_iesopt].model.objectives["total_cost"].expr) ≈ 2975.0 atol = 0.05
    @test sum(JuMP.value.(values(model.ext[:_iesopt].aux.soft_constraints_expressions))) ≈ 1
end

# NOTE: This example fails because it tries to read two snapshots from a CSV file containing only one row.
# model = JuMP.direct_model(HiGHS.Optimizer())
# generate!(model, joinpath(dir, "19_etdfs.iesopt.yaml"))
# optimize!(model)
# @test JuMP.objective_value(model) ≈ 95.7 atol = 0.1
# @test sum(JuMP.value.(values(model.ext[:_iesopt].aux.soft_constraints_expressions))) ≈ 0

@testitem "20_chp" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=16687.5)

    chp = get_component(model, "chp")
    gas = get_component(model, "create_gas")

    @test all(JuMP.value.(chp.power.exp.out_electricity) .== [2.75, 5.50, 7.00, 8.00, 9.00, 10.00, 5.00, 5.00, 9.00])
    @test all(JuMP.value.(chp.heat.exp.out_heat) .== [5.00, 10.00, 10.00, 10.00, 5.00, 0.00, 0.00, 5.00, 5.00])
    @test all(JuMP.value.(gas.exp.value) .== [9.375, 18.75, 22.5, 25.0, 25.0, 25.0, 12.5, 15.0, 25.0])
    @test maximum(abs.(JuMP.shadow_price.(chp.con.isofuel))) ≈ 850.0 atol = 0.1
end

# model = JuMP.direct_model(HiGHS.Optimizer())
# generate!(model, joinpath(dir, "21_aggregated_snapshots.iesopt.yaml"))
# optimize!(model)
# @test all(JuMP.value.(component(model, "buy").exp.value) .≈ [19.0 / 3.0, 3.0, 2.0])
# @test sum(JuMP.value.(values(model.ext[:_iesopt].aux.soft_constraints_expressions))) ≈ 0

@testitem "snapshots (22 and 23)" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.run("22_snapshot_weights")
    @test all(JuMP.value.(get_component(model, "buy").exp.value) .≈ [10.0, 6.0, 6.0, 0.0, 7.0, 4.0])

    obj_val_example_22 = JuMP.objective_value(model)

    TestExampleModule.check("23_snapshots_from_csv"; obj=obj_val_example_22)
end

# model = generate!(joinpath(dir, "24_linearized_optimal_powerflow.iesopt.yaml"))
# optimize!(model)
# @test JuMP.value(model.ext[:_iesopt].model.objectives["total_cost"].expr) ≈ 5333.16 atol = 0.05
# @test JuMP.objective_value(model) ≈ (50 * 10000 + 5333.16) atol = 0.05
# @test sum(JuMP.value.(values(model.ext[:_iesopt].aux.soft_constraints_expressions))) ≈ 50
# ac_flows = [
#     round(JuMP.value(component(model, conn).exp.pf_flow[1]); digits=3) for
#     conn in ["conn12", "conn23", "conn24", "conn34", "conn56", "conn57"]
# ]
# dc_flows = [round(JuMP.value(component(model, conn).var.flow[1]); digits=3) for conn in ["hvdc1", "hvdc2"]]
# @test all(ac_flows .== [133.368, -54.421, 187.789, 242.211, -50.0, 300.0])
# @test all(dc_flows .== [70.0, 250.0])

# todo: activate again, as soon as example is reworked
# model = JuMP.direct_model(HiGHS.Optimizer())
# generate!(model, joinpath(dir, "28_expressions.iesopt.yaml"))
# optimize!(model)
# @test JuMP.objective_value(model) ≈ 2000.0
# set_expression_term_value(component(model, "demand_value"), 1, [80 / 3, 100 / 3])
# optimize!(model)
# @test JuMP.objective_value(model) ≈ 2000.0

@testitem "31_exclusive_operation" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.run()

    @test JuMP.objective_value(model) ≈ -10.0
    @test JuMP.value.(get_component(model, "buy_id").exp.value) == [1, 0, 1, 0]
    @test JuMP.value.(get_component(model, "sell_id").exp.value) == [0, 1, 0, 1]
end

# Disabled, because Benders needs to modify Decisions (which is currently not possible due to immutability).
# @testset "Benders decomposition" begin
#     model = generate!(joinpath(PATH_EXAMPLES, "33_benders_investment.iesopt.yaml"))
#     optimize!(model)
#     _conventional_obj = JuMP.objective_value(model)
#     benders_data = benders(HiGHS.Optimizer, joinpath(PATH_EXAMPLES, "33_benders_investment.iesopt.yaml"))
#     _benders_obj = JuMP.objective_value(benders_data.main)
#     @test _conventional_obj ≈ _benders_obj atol = (_conventional_obj * 1e-4)

#     _conventional_obj = 91539936.2678  # too slow for the test
#     benders_data = benders(HiGHS.Optimizer, joinpath(PATH_EXAMPLES, "35_fixed_costs.iesopt.yaml"))
#     _benders_obj = JuMP.objective_value(benders_data.main)
#     @test _conventional_obj ≈ _benders_obj atol = (_conventional_obj * 1e-4)
# end

@testitem "37_certificates" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.run()

    @test JuMP.objective_value(model) ≈ 44376.75 atol = 0.01
    @test sum(JuMP.value.(get_component(model, "plant_gas").exp.in_gas)) ≈ 986.15 atol = 0.01
    @test sum(JuMP.value.(get_component(model, "electrolysis").exp.in_electricity)) ≈ 758.58 atol = 0.01
end

@testitem "47_disable_components" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model_coupled = TestExampleModule.run(; parameters=Dict("mode" => "coupled"))
    model_individual = TestExampleModule.run(; parameters=Dict("mode" => "individual"))
    model_AT_DE = TestExampleModule.run(; parameters=Dict("mode" => "coupled", "enable_CH" => false))
    model_CH = TestExampleModule.run(; parameters=Dict("enable_DE" => false, "enable_AT" => false))

    @test JuMP.objective_value(model_coupled) <=
          JuMP.objective_value(model_AT_DE) + JuMP.objective_value(model_CH) <=
          JuMP.objective_value(model_individual)
end

@testitem "48_custom_results" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=981.17)

    setpoint = JuMP.value.(IESopt.get_component(model, "storage").exp.setpoint)
    @test sum(setpoint) ≈ -1.09 atol = 0.01
    @test minimum(setpoint) ≈ -4.65 atol = 0.01
    @test maximum(setpoint) ≈ 3.58 atol = 0.01
end

@testitem "49_csv_format" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    cfg = String(Assets.get_path("examples", "49_csv_formats.iesopt.yaml"))

    model = generate!(cfg)
    @test size(internal(model).input.files["data"]) == (8760, 9)

    optimize!(model)
    true_obj_val =
        JuMP.objective_value(IESopt.run(String(Assets.get_path("examples", "07_csv_filestorage.iesopt.yaml"))))
    @test JuMP.objective_value(model) ≈ true_obj_val

    @test size(
        internal(
            @test_logs (:error, "[generate] Error(s) during model generation") match_mode = :any generate!(
                cfg;
                config=Dict("files._csv_config" => Dict()),
            )
        ).input.files["data"],
    ) == (8760, 8)
end

@testitem "50_delayed_connections" tags = [:examples] setup = [TestExampleModule] begin
    model = TestExampleModule.check(; obj=0.0)

    river = internal(model).results.components["river"]
    weight = 0.25
    delay = 1 // 3
    d, r = divrem(delay, weight)
    for i in get_T(model)
        first_inflow = r / weight * river.exp.in[mod1(i - Int(d) - 1, end)]
        second_inflow = (1 - r / weight) * river.exp.in[mod1(i - Int(d), end)]
        @test river.exp.out[i] == first_inflow + second_inflow
    end
end

@testitem "52_simple_ev" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=5.7895)

    @test sum(JuMP.value.(get_component(model, "ev").var.state)) ≈ 762 atol = 1e-2
    @test all(JuMP.value.(get_component(model, "ev").var.state) .<= 55.0)
end

@testitem "53_grid_tariffs" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=15.3680)

    @test JuMP.value.(get_component(model, "tariff_power_consumption").var.value) ≈ 4.5738 atol = 1e-2
    @test sum(JuMP.value.(get_component(model, "ev").var.state)) ≈ 713.5135 atol = 1e-2
end

@testitem "54_simple_roomtemperature" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=2.4501)

    @test sum(JuMP.value.(get_component(model, "house").var.state)) ≈ 510.996 atol = 1e-2
end

@testitem "55_annuity" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=2_532_909.2063)

    @test JuMP.value.(get_component(model, "pipeline.invest").var.value) ≈ 42.0 atol = 1e-2
    @test get_component(model, "pipeline.invest").cost ≈ 60067.3621 atol = 1e-2
end

@testitem "56_initial_state_decision" tags = [:examples] setup = [Dependencies, TestExampleModule] begin
    model = TestExampleModule.check(; obj=-1.7867962768e+03)

    @test JuMP.value(get_component(model, "storage").var.state[1]) == 100
end
