@setup_workload begin
    # list = [...]

    const __dir = Assets.get_path("examples")

    @compile_workload begin
        fn = String(normpath(__dir, "01_basic_single_node.iesopt.yaml"))

        @suppress safe_close_filelogger(generate!(fn; config=Dict("general.verbosity.core" => "debug")))
        
        set_global!("config", "optimization.solver.log", false)
        
        @suppress safe_close_filelogger(generate!(fn; config=Dict("general.verbosity.core" => "info")))
        @suppress safe_close_filelogger(generate!(fn; config=Dict("general.verbosity.core" => "warn")))

        set_global!("skip_validation", true)
        set_global!("config", "optimization.snapshots.count", 3)
        set_global!("config", "general.verbosity.core", "error")

        model = generate!(fn; config=Dict("results.memory_only" => true, "results.backend" => "duckdb"))
        optimize!(model)
        safe_close_filelogger(model)

        model = generate!(fn; config=Dict("results.memory_only" => false, "results.backend" => "jld2"))
        optimize!(model)
        safe_close_filelogger(model)

        model = generate!(fn; config=Dict("results.memory_only" => true, "results.backend" => "jld2"))
        optimize!(model)
        safe_close_filelogger(model)

        set_global!("config", "results.memory_only", true)

        safe_close_filelogger(IESopt.run(fn))

        safe_close_filelogger(generate!(normpath(__dir, "02_advanced_single_node.iesopt.yaml")))
        # generate!(normpath(__dir, "03_basic_two_nodes.iesopt.yaml"))
        # generate!(normpath(__dir, "04_soft_constraints.iesopt.yaml"))
        # generate!(normpath(__dir, "05_basic_two_nodes_1y.iesopt.yaml"))
        # generate!(normpath(__dir, "06_recursion_h2.iesopt.yaml"))
        safe_close_filelogger(generate!(normpath(__dir, "07_csv_filestorage.iesopt.yaml")))
        safe_close_filelogger(generate!(normpath(__dir, "08_basic_investment.iesopt.yaml")))
        safe_close_filelogger(generate!(normpath(__dir, "09_csv_only.iesopt.yaml")))
        # generate!(normpath(__dir, "10_basic_load_shedding.iesopt.yaml"))
        safe_close_filelogger(generate!(normpath(__dir, "11_basic_unit_commitment.iesopt.yaml")))
        # generate!(normpath(__dir, "12_incremental_efficiency.iesopt.yaml"))
        # generate!(normpath(__dir, "15_varying_efficiency.iesopt.yaml"))
        safe_close_filelogger(generate!(normpath(__dir, "16_noncore_components.iesopt.yaml")))
        # generate!(normpath(__dir, "17_varying_connection_capacity.iesopt.yaml"))

        model = generate!(normpath(__dir, "18_addons.iesopt.yaml"))
        get_components(model; tagged=["ModifyMe"])
        safe_close_filelogger(model)

        model = generate!(normpath(__dir, "20_chp.iesopt.yaml"))
        get_component(model, "chp")
        safe_close_filelogger(model)

        # generate!(normpath(__dir, "22_snapshot_weights.iesopt.yaml"))
        # generate!(normpath(__dir, "23_snapshots_from_csv.iesopt.yaml"))
        safe_close_filelogger(generate!(normpath(__dir, "25_global_parameters.iesopt.yaml")))
        # generate!(
        #     normpath(__dir, "26_initial_states.iesopt.yaml");
        #     parameters=Dict("store_initial_state" => 15),
        # )
        # generate!(normpath(__dir, "27_piecewise_linear_costs.iesopt.yaml"))
        # generate!(normpath(__dir, "29_advanced_unit_commitment.iesopt.yaml"))
        # generate!(normpath(__dir, "31_exclusive_operation.iesopt.yaml"))
        # generate!(normpath(__dir, "37_certificates.iesopt.yaml"))
        safe_close_filelogger(generate!(normpath(__dir, "44_lossy_connections.iesopt.yaml")))
        safe_close_filelogger(generate!(normpath(__dir, "47_disable_components.iesopt.yaml")))

        get_global("config")
        get_global("skip_validation")
    end

    # Reset global settings.
    empty!(get_global("config"))
    set_global!("skip_validation", false)

    try
        # Clean up output files after testing is done.
        rm(normpath(__dir, "out"); force=true, recursive=true)
    catch
        @warn "Failed to cleanup output files after precompilation, left-overs might be present" path =
            normpath(__dir, "out")
    end
end

precompile(_attach_optimizer, (JuMP.Model,))
