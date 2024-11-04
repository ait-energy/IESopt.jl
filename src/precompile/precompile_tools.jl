@setup_workload begin
    # list = [...]
    const dir = _PATHS[:examples]

    @compile_workload begin
        if !isnothing(Library)
            model = generate!(normpath(dir, "01_basic_single_node.iesopt.yaml"); verbosity=false)
            optimize!(model)

            generate!(normpath(dir, "08_basic_investment.iesopt.yaml"); verbosity=true)
            
            model = generate!(normpath(dir, "09_csv_only.iesopt.yaml"); verbosity=false)
            optimize!(model)

            generate!(normpath(dir, "46_constants_in_objective.iesopt.yaml"); verbosity=false)
        end
    end
end

precompile(_attach_optimizer, (JuMP.Model,))
