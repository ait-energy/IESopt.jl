@setup_workload begin
    # list = [...]

    const __dir = Assets.get_path("examples")

    @compile_workload begin
        config = Dict("optimization.snapshots.count" => 3, "general.verbosity.core" => "error")
        fn = String(normpath(__dir, "01_basic_single_node.iesopt.yaml"))

        safe_close_filelogger(generate!(fn; config=Dict("general.verbosity.core" => "debug")))
        safe_close_filelogger(generate!(fn; config=Dict("general.verbosity.core" => "info")))
        safe_close_filelogger(generate!(fn; config=Dict("general.verbosity.core" => "warn")))

        model = generate!(
            fn;
            config=Dict(
                "optimization.snapshots.count" => 3,
                "results.memory_only" => true,
                "results.backend" => "duckdb",
            ),
        )
        optimize!(model)
        safe_close_filelogger(model)

        model = generate!(
            fn;
            config=Dict(
                "optimization.snapshots.count" => 3,
                "results.memory_only" => false,
                "results.backend" => "jld2",
            ),
        )
        optimize!(model)
        safe_close_filelogger(model)

        model = generate!(
            fn;
            config=Dict(
                "optimization.snapshots.count" => 3,
                "results.memory_only" => true,
                "results.backend" => "jld2",
            ),
        )
        optimize!(model)
        safe_close_filelogger(model)

        safe_close_filelogger(IESopt.run(fn; config, skip_validation=true))

        safe_close_filelogger(
            generate!(normpath(__dir, "02_advanced_single_node.iesopt.yaml"); config, skip_validation=true),
        )
        # generate!(normpath(__dir, "03_basic_two_nodes.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "04_soft_constraints.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "05_basic_two_nodes_1y.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "06_recursion_h2.iesopt.yaml"); config, skip_validation=true)
        safe_close_filelogger(
            generate!(normpath(__dir, "07_csv_filestorage.iesopt.yaml"); config, skip_validation=true),
        )
        safe_close_filelogger(
            generate!(normpath(__dir, "08_basic_investment.iesopt.yaml"); config, skip_validation=true),
        )
        safe_close_filelogger(generate!(normpath(__dir, "09_csv_only.iesopt.yaml"); config, skip_validation=true))
        # generate!(normpath(__dir, "10_basic_load_shedding.iesopt.yaml"); config, skip_validation=true)
        safe_close_filelogger(
            generate!(normpath(__dir, "11_basic_unit_commitment.iesopt.yaml"); config, skip_validation=true),
        )
        # generate!(normpath(__dir, "12_incremental_efficiency.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "15_varying_efficiency.iesopt.yaml"); config, skip_validation=true)
        safe_close_filelogger(
            generate!(normpath(__dir, "16_noncore_components.iesopt.yaml"); config, skip_validation=true),
        )
        # generate!(normpath(__dir, "17_varying_connection_capacity.iesopt.yaml"); config, skip_validation=true)

        model = generate!(normpath(__dir, "18_addons.iesopt.yaml"); config, skip_validation=true)
        get_components(model; tagged=["ModifyMe"])
        safe_close_filelogger(model)

        model = generate!(normpath(__dir, "20_chp.iesopt.yaml"); config, skip_validation=true)
        get_component(model, "chp")
        safe_close_filelogger(model)

        # generate!(normpath(__dir, "22_snapshot_weights.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "23_snapshots_from_csv.iesopt.yaml"); config, skip_validation=true)
        safe_close_filelogger(
            generate!(normpath(__dir, "25_global_parameters.iesopt.yaml"); config, skip_validation=true),
        )
        # generate!(
        #     normpath(__dir, "26_initial_states.iesopt.yaml");
        #     config,
        #     parameters=Dict("store_initial_state" => 15),
        #     skip_validation=true,
        # )
        # generate!(normpath(__dir, "27_piecewise_linear_costs.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "29_advanced_unit_commitment.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "31_exclusive_operation.iesopt.yaml"); config, skip_validation=true)
        # generate!(normpath(__dir, "37_certificates.iesopt.yaml"); config=Dict("general.verbosity.core" => "error"))
        safe_close_filelogger(
            generate!(normpath(__dir, "44_lossy_connections.iesopt.yaml"); config, skip_validation=true),
        )
        safe_close_filelogger(
            generate!(normpath(__dir, "47_disable_components.iesopt.yaml"); config, skip_validation=true),
        )
    end

    # Clean up output files after testing is done.
    rm(normpath(__dir, "out"); force=true, recursive=true)
end

precompile(_attach_optimizer, (JuMP.Model,))
