"""
    _prepare_config_general!(model::JuMP.Model)

Prepare the general configuration section.

# Structure:

```yaml
config:
    general:
        version:
            core: 1.1.0         # NO DEFAULT
            python: 1.1.0       # NO DEFAULT
        name:
            model: my_model
            scenario: my_scenario
        verbosity:
            core: info
            progress: on        # DEFAULT: `verbosity.core` == "error" => "off", else "on"
            python: info        # DEFAULT: `verbosity.core`
            solver: on          # DEFAULT: `verbosity.core` == "error" => "off", else "on"
```
"""
function _prepare_config_general!(model::JuMP.Model)
    data = get(internal(model).input._tl_yaml["config"], "general", Dict{String, Any}())

    @config(model, general) = Dict{String, Dict{String, String}}()

    # Verbosity.
    haskey(data, "verbosity") || (data["verbosity"] = Dict{String, String}())
    verbosity_core = get(data["verbosity"], "core", "info")::String
    verbosity_bool_default = verbosity_core == "error" ? "off" : "on"
    @config(model, general.verbosity) = Dict{String, String}(
        "core" => replace(verbosity_core, "warning" => "warn"),
        "progress" => get(data["verbosity"], "progress", verbosity_bool_default)::String,
        "python" => replace(get(data["verbosity"], "python", verbosity_core)::String, "warning" => "warn"),
        "solver" => get(data["verbosity"], "solver", verbosity_bool_default)::String,
    )

    # Validation checks.
    if !haskey(data, "version")
        if @config(model, general.verbosity.core, String) != "error"
            @warn "Missing `version` specification in the configuration file - consider adding it now, see: https://ait-energy.github.io/iesopt/pages/manual/yaml/top_level.html#version"
        end
        data["version"] = Dict{String, String}("core" => string(pkgversion(@__MODULE__)), "python" => "missing")
    end

    # Version.
    @config(model, general.version) = Dict{String, String}(string(k) => string(v) for (k, v) in data["version"])

    # Name.
    haskey(data, "name") || (data["name"] = Dict{String, String}())
    _time = ("\$TIME\$" => Dates.format(Dates.now(), "yyyy_mm_dd_HHMMSSs"))
    @config(model, general.name) = Dict{String, String}(
        "model" => replace(get(data["name"], "model", "my_model")::String, _time),
        "scenario" => replace(get(data["name"], "scenario", "my_scenario")::String, _time),
    )

    # Performance.
    performance = get(data, "performance", Dict{String, Bool}())
    @config(model, general.performance) = Dict(
        "string_names" => get(performance, "string_names", true)::Bool,
        "logfile" => get(performance, "logfile", true)::Bool,
        "force_addon_reload" => get(performance, "force_addon_reload", true)::Bool,
    )

    return nothing
end
