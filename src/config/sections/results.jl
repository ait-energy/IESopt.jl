function _prepare_config_results!(model::JuMP.Model)
    data = get(internal(model).input._tl_yaml["config"], "results", Dict{String, String}())

    @config(model, results) = Dict{String, Union{Symbol, Bool}}()

    # Enabled.
    if haskey(data, "disabled")
        @warn "The `disabled` entry in `results` is deprecated; use `enabled` instead"
    end
    results_enabled = get(data, "enabled", !get(data, "disabled", false))
    if results_enabled === true
        @warn "Passing `true` to `results.enabled` is deprecated; use `all`, or any other specific setting instead"
        results_enabled = "all"
    end
    if results_enabled === false
        @warn "Passing `false` to `results.enabled` is deprecated; use `none` instead"
        results_enabled = "none"
    end
    @config(model, results.enabled) = Symbol(results_enabled)

    # Memory only.
    memory_only = get(data, "memory_only", true)::Bool
    @config(model, results.memory_only) = memory_only

    # Compress.
    compress = get(data, "compress", false)::Bool
    if memory_only && compress
        @warn "The `memory_only` and `compress` entries in `results` are incompatible; ignoring `compress`"
        compress = false
    end
    @config(model, results.compress) = compress

    # Include.
    included_modes = lowercase(get(data, "include", memory_only ? "none" : "input+log"))::String
    included_modes = string(replace(included_modes, "all" => "input+git+log"))::String
    @config(model, results.include) = Set(Symbol.(split(included_modes, '+')))

    # Backend.
    @config(model, results.backend) = Symbol(get(data, "backend", "jld2"))::Symbol

    return nothing
end
