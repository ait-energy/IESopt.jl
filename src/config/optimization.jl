struct _ConfigSolver
    name::String
    mode::String
    log::Bool
    attributes::Dict{String, Any}
end

struct _ConfigSnapshots
    count::Int64
    offset::Int64

    names::Union{String, Nothing}
    weights::Union{String, Float64, Nothing}

    representatives::Union{String, Nothing}
    aggregate::Union{Float64, Nothing}
end

struct _ConfigObjective
    current::Union{String, Nothing}
    functions::Dict{String, Vector{String}}
end

struct _ConfigMultiObjective
    mode::String
    terms::Vector{String}
    settings::Dict{String, Any}
end

struct _ConfigOptimization
    problem_type::Set{Symbol}
    snapshots::_ConfigSnapshots
    solver::_ConfigSolver

    objective::_ConfigObjective
    multiobjective::Union{_ConfigMultiObjective, Nothing}

    constraint_safety::Bool
    constraint_safety_cost::Float64

    high_performance::Bool
end

function _ConfigOptimization(config::Dict{String, Any})
    problem_types = Set(Symbol.(split(lowercase(config["problem_type"]), "+")))

    return _ConfigOptimization(
        problem_types,
        _ConfigSnapshots(get(config, "snapshots", Dict{String, Any}())),
        _ConfigSolver(get(config, "solver", Dict{String, Any}())),
        _ConfigObjective(config),
        _ConfigMultiObjective(config),
        get(config, "constraint_safety", false),
        get(config, "constraint_safety_cost", 1e5),
        get(config, "high_performance", false),
    )
end

function _ConfigObjective(config::Dict{String, Any})
    objectives = get(config, "objectives", Dict{String, Vector{String}}())
    haskey(objectives, "total_cost") || (objectives["total_cost"] = Vector{String}())

    return _ConfigObjective(
        get(config, "objective", haskey(config, "multiobjective") ? nothing : "total_cost"),
        objectives,
    )
end

function _ConfigMultiObjective(config::Dict{String, Any})
    haskey(config, "multiobjective") || return nothing

    return _ConfigMultiObjective(
        config["multiobjective"]["mode"],
        config["multiobjective"]["terms"],
        config["multiobjective"]["settings"],
    )
end

function _ConfigSnapshots(config::Dict{String, Any})
    count = config["count"]
    if _is_precompiling()
        count = min(4, count)
        @warn "Detected precompilation... limiting Snapshot count" original = config["count"] new = count
    end

    return _ConfigSnapshots(
        count,
        get(config, "offset", 0),
        get(config, "names", nothing),
        get(config, "weights", nothing),
        get(config, "representatives", nothing),
        get(config, "aggregate", nothing),
    )
end

function _ConfigSolver(config::Dict{String, Any})
    # todo: implement default attributes depending on solver 
    return _ConfigSolver(
        lowercase(get(config, "name", "highs")),
        lowercase(get(config, "mode", "normal")),
        get(config, "log", true),
        get(config, "attributes", Dict{String, Any}()),
    )
end
