function _prepare_config_optimization!(model::JuMP.Model)
    data = get(internal(model).input._tl_yaml["config"], "optimization", Dict{String, Any}())

    @config(model, optimization) = Dict{String, Dict{String, Any}}()

    # Problem type(s).
    @config(model, optimization.problem_type) = Set(Symbol.(split(lowercase(data["problem_type"]), "+")))

    # Solver.
    data_solver = get(data, "solver", Dict{String, Any}())
    @config(model, optimization.solver) = Dict(
        "name" => lowercase(get(data_solver, "name", "highs"))::String,
        "mode" => lowercase(get(data_solver, "mode", "normal"))::String,
        "log" => get(data_solver, "log", true)::Bool,
        "attributes" => get(data_solver, "attributes", Dict{String, Any}())::Dict{String, Any},
    )

    # Snapshots.
    data_snapshots = get(data, "snapshots", Dict{String, Any}())
    count = data_snapshots["count"]
    weight_config = get(data_snapshots, "weights", nothing)
    weights = weight_config isa Real ? float(weight_config) : weight_config
    @config(model, optimization.snapshots) = Dict{String, Any}(
        "count" => count::Int64,
        "offset" => get(data_snapshots, "offset", 0)::Int64,
        "names" => get(data_snapshots, "names", nothing),
        "weights" => weights,
        "representatives" => get(data_snapshots, "representatives", nothing),
        "aggregate" => get(data_snapshots, "aggregate", nothing),
    )
    if haskey(data_snapshots, "offset_virtual_files")
        @config(model, optimization.snapshots.offset_virtual_files) = data_snapshots["offset_virtual_files"]::Bool
    end

    # Objectives.
    objectives = get(data, "objectives", Dict{String, Vector{String}}())
    haskey(objectives, "total_cost") || (objectives["total_cost"] = Vector{String}())
    @config(model, optimization.objective) = Dict(
        "current" => get(data, "objective", haskey(data, "multiobjective") ? nothing : "total_cost"),
        "functions" => objectives,
    )

    # TODO: config.optimization.objective is missing from the docs

    # Multi-objective.
    if !haskey(data, "multiobjective")
        @config(model, optimization.multiobjective) = Dict{String, Union{String, Vector, Dict}}()
    else
        @config(model, optimization.multiobjective) = Dict(
            "mode" => data["multiobjective"]["mode"]::String,
            "terms" => get(data["multiobjective"], "terms", String[])::Vector{String},
            "settings" => get(data["multiobjective"], "settings", Dict{String, Any}())::Dict{String, Any},
        )
    end

    # Soft constraints (old: constraint safety).
    @config(model, optimization.soft_constraints) = Dict{String, Union{Bool, Float64}}()
    if haskey(data, "soft_constraints")
        @config(model, optimization.soft_constraints.active) = data["soft_constraints"]["active"]::Bool
        @config(model, optimization.soft_constraints.penalty) = convert(Float64, data["soft_constraints"]["penalty"])
    else
        @config(model, optimization.soft_constraints.active) = false
        @config(model, optimization.soft_constraints.penalty) = 0.0
    end

    return nothing
end
