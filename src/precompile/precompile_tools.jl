@setup_workload begin
    # list = [...]

    @compile_workload begin
        config = Dict("optimization.snapshots.count" => 3, "general.verbosity.core" => "error")
        fn = String(Assets.get_path("examples", "01_basic_single_node.iesopt.yaml"))

        generate!(fn; config=Dict("general.verbosity.core" => "debug"))
        generate!(fn; config=Dict("general.verbosity.core" => "info"))
        generate!(fn; config=Dict("general.verbosity.core" => "warn"))
        model = generate!(fn; config)
        optimize!(model)
        model = generate!(
            fn;
            config=Dict(
                "optimization.snapshots.count" => 3,
                "results.memory_only" => false,
                "results.backend" => "jld2",
            ),
        )
        optimize!(model)
        model = generate!(
            fn;
            config=Dict(
                "optimization.snapshots.count" => 3,
                "results.memory_only" => true,
                "results.backend" => "jld2",
            ),
        )
        optimize!(model)
        IESopt.run(fn; config)
        generate!(Assets.get_path("examples", "02_advanced_single_node.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "03_basic_two_nodes.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "04_soft_constraints.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "05_basic_two_nodes_1y.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "06_recursion_h2.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "07_csv_filestorage.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "08_basic_investment.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "09_csv_only.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "10_basic_load_shedding.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "11_basic_unit_commitment.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "12_incremental_efficiency.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "15_varying_efficiency.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "16_noncore_components.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "17_varying_connection_capacity.iesopt.yaml"); config)

        model = generate!(Assets.get_path("examples", "18_addons.iesopt.yaml"); config)
        get_components(model; tagged=["ModifyMe"])

        model = generate!(Assets.get_path("examples", "20_chp.iesopt.yaml"); config)
        get_component(model, "chp")

        generate!(Assets.get_path("examples", "22_snapshot_weights.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "23_snapshots_from_csv.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "25_global_parameters.iesopt.yaml"); config)
        generate!(
            Assets.get_path("examples", "26_initial_states.iesopt.yaml");
            config,
            parameters=Dict("store_initial_state" => 15),
        )
        generate!(Assets.get_path("examples", "27_piecewise_linear_costs.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "29_advanced_unit_commitment.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "31_exclusive_operation.iesopt.yaml"); config)
        generate!(
            Assets.get_path("examples", "37_certificates.iesopt.yaml");
            config=Dict("general.verbosity.core" => "error"),
        )
        generate!(Assets.get_path("examples", "44_lossy_connections.iesopt.yaml"); config)
        generate!(Assets.get_path("examples", "47_disable_components.iesopt.yaml"); config)

        # Clean up output files after testing is done.
        rm(normpath(Assets.get_path("examples"), "out"); force=true, recursive=true)
    end
end

precompile(_attach_optimizer, (JuMP.Model,))
