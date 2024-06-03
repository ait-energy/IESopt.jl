include("names.jl")
include("paths.jl")
include("files.jl")
include("results.jl")
include("optimization.jl")

struct _Config
    names::_ConfigNames

    optimization::_ConfigOptimization
    files::_ConfigFiles
    results::_ConfigResults
    paths::_ConfigPaths

    progress::Bool
    verbosity::Union{String, Bool}
    verbosity_solve::Bool

    parametric::Bool    # todo: remove / refactor after "expression rework"
end

function _Config(model::JuMP.Model)
    config = _iesopt(model).input._tl_yaml["config"]

    model_path = model.ext[:_iesopt_wd]
    verbosity = model.ext[:_iesopt_verbosity]

    names_str = (
        if !haskey(config, "name")
            ("my_model", "scenario_\$TIME\$")
        else
            if haskey(config["name"], "run")
                @warn "Using `run` in the `name` section of the configuration is deprecated, use `scenario` instead"
            end

            name_model = get(config["name"], "model", "my_model")
            name_scenario = get(config["name"], "scenario", get(config["name"], "run", "scenario_\$TIME\$"))
            (name_model, name_scenario)
        end
    )
    names = _ConfigNames(replace.(names_str, "\$TIME\$" => Dates.format(Dates.now(), "yyyy_mm_dd_HHMMSSs"))...)
    paths = _ConfigPaths(get(config, "paths", Dict{String, Any}()), model_path, names)

    verbosity = isnothing(verbosity) ? get(config, "verbosity", true) : verbosity
    return _Config(
        names,
        _ConfigOptimization(get(config, "optimization", Dict{String, Any}())),
        _ConfigFiles(get(config, "files", Dict{String, Any}()), paths),
        _ConfigResults(get(config, "results", Dict{String, Any}())),
        paths,
        get(config, "progress", verbosity === true),
        verbosity,
        get(config, "verbosity_solve", verbosity === true),
        false,
    )
end

_has_representative_snapshots(model::JuMP.Model) =
    !isnothing(_iesopt_config(model).optimization.snapshots.representatives)
_is_multiobjective(model::JuMP.Model) = (:mo in _iesopt_config(model).optimization.problem_type)
_is_lp(model::JuMP.Model) = (:lp in _iesopt_config(model).optimization.problem_type)
_is_milp(model::JuMP.Model) = (:milp in _iesopt_config(model).optimization.problem_type)
