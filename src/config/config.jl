include("sections/general.jl")
include("sections/optimization.jl")
include("sections/files.jl")
include("sections/results.jl")
include("sections/paths.jl")

"""
    _nest_recursive(settings::Union{AbstractDict, NamedTuple, Base.Pairs})

Return a nested `Dict{String, Any}` representation of `settings`
expanding all `.` occurences in keys to another nesting level.

This turns any of

    Dict("a.b.c" => x, "a.d" => y)
    (; a=(; b=(; c=x), d=y))
    Dict("a" => Dict("b.c" => x, "d" => y))

into

    Dict{String, Any}(
        "a" => Dict{String, Any}(
            "b" => Dict{String, Any}(
                "c" => x,
            ),
            "d" => y,
        ),
    )
"""
function _nest_recursive(settings::Union{AbstractDict, NamedTuple, Base.Pairs})
    return _merge_recursive!((_nest_recursive(k, _nest_recursive(v)) for (k, v) in pairs(settings))...)
end
_nest_recursive(v) = v
function _nest_recursive(key, settings)
    if contains(string(key), ".")
        k, v = rsplit(string(key), "."; limit=2)
        return _nest_recursive(k, Dict{String, Any}(string(v) => settings))
    else
        return Dict{String, Any}(string(key) => settings)
    end
end

"""
    _flatten_recursive(settings::Union{AbstractDict, NamedTuple, Base.Pairs})

Return a flattened `Dict{String, Any}` representation of `settings`
collapsing all nesting levels into `.`-separated keys.

This turns any of

    Dict("a.b.c" => x, "a.d" => y)
    (; a=(; b=(; c=x), d=y))
    Dict("a" => Dict("b.c" => x, "d" => y))

into

    Dict{String, Any}(
        "a.b.c" => x,
        "a.d" => y,
    )
"""
function _flatten_recursive(settings::Union{AbstractDict, NamedTuple, Base.Pairs})
    return _merge_recursive!((_flatten_recursive(k, _flatten_recursive(v)) for (k, v) in pairs(settings))...)
end
_flatten_recursive(value) = value
function _flatten_recursive(key, settings::Union{AbstractDict, NamedTuple, Base.Pairs})
    return Dict{String, Any}(string(key, ".", k) => v for (k, v) in pairs(settings))
end
_flatten_recursive(key, value) = Dict{String, Any}(string(key) => value)

"""
    _nest_once(settings)

Add one nesting level "at the end" of a flattened `Dict` settings.

This turns

    Dict{String, Any}(
        "a.b.c" => x,
        "a.d" => y,
    )

into

    Dict{String, Any}(
        "a.b" => Dict{String,Any}("c" => x),
        "a" => Dict{String, Any}("d" => y),
    )
"""
function _nest_once(settings)
    return _merge_recursive!((_nest_once(k, v) for (k, v) in pairs(settings))...)
end
function _nest_once(key, value)
    k, v = rsplit(string(key), "."; limit=2)
    return Dict{String, Any}(string(k) => Dict{String, Any}(string(v) => value))
end

"""
    _merge_recursive!(d::Dict...)

Recursively merge all nesting levels of all `Dict`s in `d` into the first `Dict` in `d`.
"""
_merge_recursive!(d::Dict...) = merge!(_merge_recursive!, d...)
_merge_recursive!(x...) = last(x)

function _replace_config_from_user!(model::JuMP.Model)
    config = internal(model).input._tl_yaml["config"]
    kwargs = model.ext[:_iesopt_kwargs][:config]
    if !isempty(kwargs)
        _merge_recursive!(config, _nest_recursive(kwargs))
    end
    return nothing
end

function _replace_components_from_user!(description, model::JuMP.Model)
    kwargs = model.ext[:_iesopt_kwargs][:components]
    isempty(kwargs) && return description
    _merge_recursive!(description, _nest_once(_flatten_recursive(kwargs)))
    return nothing
end

function _prepare_config_and_logger!(model::JuMP.Model)
    _replace_config_from_user!(model)

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
