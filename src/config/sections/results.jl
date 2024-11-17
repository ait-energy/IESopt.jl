function _prepare_config_results!(model::JuMP.Model)
    data = get(internal(model).input._tl_yaml["config"], "results", Dict{String, String}())

    @config(model, results) = Dict{String, Union{Symbol, Bool}}()

    # Enabled.
    @config(model, results.enabled) = get(data, "enabled", !get(data, "disabled", false))::Bool

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
    @config(model, results.backend) = Symbol(get(data, "backend", "duckdb"))::Symbol

    return nothing
end
