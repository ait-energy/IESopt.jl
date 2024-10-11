function _test_example_default_solver(filename::String; obj::Float64, verbosity::Union{Bool, String}=false, kwargs...)
    @testset "$(split(filename, ".")[1])" begin
        model = @suppress generate!(joinpath(PATH_EXAMPLES, filename); verbosity=verbosity, kwargs...)
        @suppress optimize!(model)
        @test JuMP.objective_value(model) ≈ obj atol = 0.1
        IESopt.save_close_filelogger(model)
    end
end

# Run basic tests that check the objective value of the example against a prerecorded value.
_test_example_default_solver("01_basic_single_node.iesopt.yaml"; obj=525.0)
_test_example_default_solver("02_advanced_single_node.iesopt.yaml"; obj=1506.75, verbosity=true)
_test_example_default_solver("03_basic_two_nodes.iesopt.yaml"; obj=1225.0, verbosity="warning")
_test_example_default_solver("05_basic_two_nodes_1y.iesopt.yaml"; obj=667437.8)
_test_example_default_solver("06_recursion_h2.iesopt.yaml"; obj=18790.8)
_test_example_default_solver("07_csv_filestorage.iesopt.yaml"; obj=667437.8)
_test_example_default_solver("08_basic_investment.iesopt.yaml"; obj=2015.6)
_test_example_default_solver("09_csv_only.iesopt.yaml"; obj=667437.8)
_test_example_default_solver("10_basic_load_shedding.iesopt.yaml"; obj=25000 + 1083.9)
_test_example_default_solver("11_basic_unit_commitment.iesopt.yaml"; obj=1570.0)
_test_example_default_solver("12_incremental_efficiency.iesopt.yaml"; obj=3570.0)
_test_example_default_solver("15_varying_efficiency.iesopt.yaml"; obj=2131435.8)
_test_example_default_solver("16_noncore_components.iesopt.yaml"; obj=4372.2)
_test_example_default_solver("17_varying_connection_capacity.iesopt.yaml"; obj=300.0)
_test_example_default_solver("18_addons.iesopt.yaml"; obj=85.0)
_test_example_default_solver("25_global_parameters.iesopt.yaml"; obj=50.0)
_test_example_default_solver("25_global_parameters.iesopt.yaml"; obj=100.0, demand=10)
_test_example_default_solver("26_initial_states.iesopt.yaml"; obj=150.0, store_initial_state=15)
_test_example_default_solver("26_initial_states.iesopt.yaml"; obj=0.0, store_initial_state=50)
_test_example_default_solver("27_piecewise_linear_costs.iesopt.yaml"; obj=450.0)
_test_example_default_solver("29_advanced_unit_commitment.iesopt.yaml"; obj=7000.0)
_test_example_default_solver("30_representative_snapshots.iesopt.yaml"; obj=319100.0)
_test_example_default_solver("44_lossy_connections.iesopt.yaml"; obj=1233.75)

# Run tests that manually check various outcomes of example models.

@testset "04_constraint_safety" begin
    model = generate!(joinpath(PATH_EXAMPLES, "04_constraint_safety.iesopt.yaml"); verbosity=false)
    optimize!(model)
    @test JuMP.value(model.ext[:iesopt].model.objectives["total_cost"].expr) ≈ 2975.0 atol = 0.05
    @test sum(JuMP.value.(values(model.ext[:iesopt].aux.constraint_safety_expressions))) ≈ 1
    IESopt.save_close_filelogger(model)
end

# NOTE: This example fails because it tries to read two snapshots from a CSV file containing only one row.
# model = JuMP.direct_model(HiGHS.Optimizer())
# generate!(model, joinpath(dir, "19_etdfs.iesopt.yaml"); verbosity=false)
# optimize!(model)
# @test JuMP.objective_value(model) ≈ 95.7 atol = 0.1
# @test sum(JuMP.value.(values(model.ext[:iesopt].aux.constraint_safety_expressions))) ≈ 0

@testset "20_chp" begin
    model = generate!(joinpath(PATH_EXAMPLES, "20_chp.iesopt.yaml"); verbosity=false)
    optimize!(model)
    @test all(
        JuMP.value.(get_component(model, "chp.power").exp.out_electricity) .==
        [2.75, 5.50, 7.00, 8.00, 9.00, 10.00, 5.00, 5.00, 9.00],
    )
    @test all(
        JuMP.value.(get_component(model, "chp.heat").exp.out_heat) .==
        [5.00, 10.00, 10.00, 10.00, 5.00, 0.00, 0.00, 5.00, 5.00],
    )
    @test all(
        JuMP.value.(get_component(model, "create_gas").exp.value) .==
        [9.375, 18.75, 22.5, 25.0, 25.0, 25.0, 12.5, 15.0, 25.0],
    )
    IESopt.save_close_filelogger(model)
end

# model = JuMP.direct_model(HiGHS.Optimizer())
# generate!(model, joinpath(dir, "21_aggregated_snapshots.iesopt.yaml"))
# optimize!(model)
# @test all(JuMP.value.(component(model, "buy").exp.value) .≈ [19.0 / 3.0, 3.0, 2.0])
# @test sum(JuMP.value.(values(model.ext[:iesopt].aux.constraint_safety_expressions))) ≈ 0

@testset "snapshots (22 and 23)" begin
    model = generate!(joinpath(PATH_EXAMPLES, "22_snapshot_weights.iesopt.yaml"); verbosity=false)
    optimize!(model)
    @test all(JuMP.value.(get_component(model, "buy").exp.value) .≈ [10.0, 6.0, 6.0, 0.0, 7.0, 4.0])
    obj_val_example_22 = JuMP.objective_value(model)
    _test_example_default_solver("23_snapshots_from_csv.iesopt.yaml"; obj=obj_val_example_22)
    IESopt.save_close_filelogger(model)
end

# model = generate!(joinpath(dir, "24_linearized_optimal_powerflow.iesopt.yaml"); verbosity=false)
# optimize!(model)
# @test JuMP.value(model.ext[:iesopt].model.objectives["total_cost"].expr) ≈ 5333.16 atol = 0.05
# @test JuMP.objective_value(model) ≈ (50 * 10000 + 5333.16) atol = 0.05
# @test sum(JuMP.value.(values(model.ext[:iesopt].aux.constraint_safety_expressions))) ≈ 50
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

@testset "31_exclusive_operation" begin
    model = generate!(joinpath(PATH_EXAMPLES, "31_exclusive_operation.iesopt.yaml"); verbosity=false)
    optimize!(model)
    @test JuMP.objective_value(model) ≈ -10.0
    @test JuMP.value.(IESopt.get_component(model, "buy_id").exp.value) == [1, 0, 1, 0]
    @test JuMP.value.(IESopt.get_component(model, "sell_id").exp.value) == [0, 1, 0, 1]
    IESopt.save_close_filelogger(model)
end

# Disabled, because Benders needs to modify Decisions (which is currently not possible due to immutability).
# @testset "Benders decomposition" begin
#     model = generate!(joinpath(PATH_EXAMPLES, "33_benders_investment.iesopt.yaml"); verbosity=false)
#     optimize!(model)
#     _conventional_obj = JuMP.objective_value(model)
#     benders_data = benders(HiGHS.Optimizer, joinpath(PATH_EXAMPLES, "33_benders_investment.iesopt.yaml"); verbosity=false)
#     _benders_obj = JuMP.objective_value(benders_data.main)
#     @test _conventional_obj ≈ _benders_obj atol = (_conventional_obj * 1e-4)

#     _conventional_obj = 91539936.2678  # too slow for the test
#     benders_data = benders(HiGHS.Optimizer, joinpath(PATH_EXAMPLES, "35_fixed_costs.iesopt.yaml"); verbosity=false)
#     _benders_obj = JuMP.objective_value(benders_data.main)
#     @test _conventional_obj ≈ _benders_obj atol = (_conventional_obj * 1e-4)
# end

@testset "37_certificates" begin
    model = generate!(joinpath(PATH_EXAMPLES, "37_certificates.iesopt.yaml"); verbosity=false)
    optimize!(model)
    @test JuMP.objective_value(model) ≈ 44376.75 atol = 0.01
    @test sum(IESopt.extract_result(model, "plant_gas", "in:gas"; mode="value")) ≈ 986.15 atol = 0.01
    @test sum(IESopt.extract_result(model, "electrolysis", "in:electricity"; mode="value")) ≈ 758.58 atol = 0.01
    IESopt.save_close_filelogger(model)
end

@testset "47_disable_components" begin
    model_coupled =
        generate!(joinpath(PATH_EXAMPLES, "47_disable_components.iesopt.yaml"); mode="coupled", verbosity=false)
    model_individual =
        generate!(joinpath(PATH_EXAMPLES, "47_disable_components.iesopt.yaml"); mode="individual", verbosity=false)
    model_AT_DE = generate!(
        joinpath(PATH_EXAMPLES, "47_disable_components.iesopt.yaml");
        mode="coupled",
        enable_CH=false,
        verbosity=false,
    )
    model_CH = generate!(
        joinpath(PATH_EXAMPLES, "47_disable_components.iesopt.yaml");
        enable_DE=false,
        enable_AT=false,
        verbosity=false,
    )
    optimize!(model_coupled)
    optimize!(model_individual)
    optimize!(model_AT_DE)
    optimize!(model_CH)
    @test JuMP.objective_value(model_coupled) <=
          JuMP.objective_value(model_AT_DE) + JuMP.objective_value(model_CH) <=
          JuMP.objective_value(model_individual)

    IESopt.save_close_filelogger(model_coupled)
    IESopt.save_close_filelogger(model_individual)
    IESopt.save_close_filelogger(model_AT_DE)
    IESopt.save_close_filelogger(model_CH)
end

# Clean up output files after testing is done.
rm(joinpath(PATH_EXAMPLES, "out"); force=true, recursive=true)
