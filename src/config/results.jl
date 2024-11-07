struct _ConfigResults
    enabled::Bool
    memory_only::Bool
    compress::Bool
    include::Set{Symbol}
end

function _ConfigResults(config::Dict{String, Any})
    if isempty(config)
        return _ConfigResults(true, true, false, Set())
    end

    enabled = get(config, "enabled", !get(config, "disabled", false))
    if !enabled
        @warn "Automatic result extraction disabled"
        return _ConfigResults(false, false, false, Set())
    end

    for entry in ["document", "settings", "groups"]
        haskey(config, entry) || continue
        @error "The `$(entry)` entry in `results` is deprecated will not work as expected"
    end

    memory_only = get(config, "memory_only", true)
    compress = get(config, "compress", false)
    included_modes = lowercase(get(config, "include", memory_only ? "none" : "input+log"))
    included_modes = string.(replace(included_modes, "all" => "input+git+log"))

    if memory_only
        if compress
            @error "The `memory_only` and `compress` entries in `results` are incompatible; ignoring `compress`"
        end
    end

    return _ConfigResults(enabled, memory_only, compress, Set(Symbol.(split(included_modes, '+'))))
end
