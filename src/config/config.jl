include("sections/general.jl")
include("sections/optimization.jl")
include("sections/files.jl")
include("sections/results.jl")
include("sections/paths.jl")

function _replace_config_from_user(model::JuMP.Model)
    isempty(model.ext[:_iesopt_kwargs][:config]) && return nothing
    data = internal(model).input._tl_yaml["config"]

    for (k, v) in model.ext[:_iesopt_kwargs][:config]
        accessors = split(k, '.')
        current = data
        for (i, accessor) in enumerate(accessors)
            if i == length(accessors)
                current[accessor] = v
            else
                current = get!(current, accessor, Dict{String, Any}())
            end
        end
    end
end

function _prepare_config_and_logger!(model::JuMP.Model)
    _replace_config_from_user(model)

    _prepare_config_general!(model)

    verbosity = @config(model, general.verbosity.core, String)

    if !(verbosity in ["debug", "info", "warn", "error"])
        @warn "Unsupported `verbosity` config. Choose from `debug`, `info`, `warn`, or `error`. Falling back to `info`."
        @config(model, general.verbosity.core) = verbosity = "info"
    end

    logger = Logging.ConsoleLogger(
        global_logger().stream,
        Logging.LogLevel(getfield(Logging, Symbol(uppercasefirst(verbosity)))),
    )

    return logger
end

function _prepare_config!(model::JuMP.Model)
    with_logger(_prepare_config_and_logger!(model)) do
        _prepare_config_optimization!(model)
        _prepare_config_files!(model)
        _prepare_config_results!(model)
        _prepare_config_paths!(model)

        v_curr = VersionNumber(string(pkgversion(@__MODULE__))::String)
        v_core = VersionNumber(@config(model, general.version.core)::String)
        if (v_core.major != v_curr.major) || (v_curr < v_core)
            @error "The required `version.core` (v$(v_core)) in the configuration file is not compatible with the current version of `IESopt.jl` (v$(v_curr)), which might lead to unexpected behavior or errors"
        end

        unknown_sections = [
            k for k in keys(internal(model).input._tl_yaml["config"]) if
            !(k in ["general", "optimization", "files", "results", "paths"])
        ]
        if !isempty(unknown_sections)
            @error "Unknown configuration sections found in the configuration file: $(join(unknown_sections, ", "))"
        end

        @debug "Configuration loaded"
        @debug "[general]" Dict(Symbol(k) => v for (k, v) in @config(model, general))...
        @debug "[optimization]" Dict(Symbol(k) => v for (k, v) in @config(model, optimization))...
        @debug "[files]" Dict(Symbol(k) => v for (k, v) in @config(model, files))...
        @debug "[results]" Dict(Symbol(k) => v for (k, v) in @config(model, results))...
        @debug "[paths]" Dict(Symbol(k) => v for (k, v) in @config(model, paths))...
    end

    return nothing
end

# "parametric" ?

_has_representative_snapshots(model::JuMP.Model) = false  # TODO

_is_multiobjective(model::JuMP.Model) = (:mo in @config(model, optimization.problem_type))::Bool
_is_lp(model::JuMP.Model) = (:lp in @config(model, optimization.problem_type))::Bool
_is_milp(model::JuMP.Model) = (:milp in @config(model, optimization.problem_type))::Bool
_is_qp(model::JuMP.Model) = (:qp in @config(model, optimization.problem_type))::Bool
_is_parametric(model::JuMP.Model) = (:parametric in @config(model, optimization.problem_type))::Bool
