@setup_workload begin
    # list = [...]
    const dir = Assets.get_path("examples")

    @compile_workload begin
        model = generate!(normpath(dir, "01_basic_single_node.iesopt.yaml"))
        optimize!(model)

        generate!(normpath(dir, "08_basic_investment.iesopt.yaml"))

        model = generate!(normpath(dir, "09_csv_only.iesopt.yaml"))
        optimize!(model)

        generate!(normpath(dir, "46_constants_in_objective.iesopt.yaml"))

        fn = normpath(dir, "01_basic_single_node.iesopt.yaml")
        generate!(fn; config=Dict("general.verbosity.core" => "debug"))
        generate!(fn; config=Dict("general.verbosity.core" => "info"))
        generate!(fn; config=Dict("general.verbosity.core" => "warn"))
        generate!(fn; config=Dict("general.verbosity.core" => "error"))
    end
end

precompile(_attach_optimizer, (JuMP.Model,))
