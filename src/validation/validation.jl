function _vassert(condition::Bool, message::String; kwargs...)::Bool
    condition || (@error "Validation error: $(message)" kwargs...)
    return condition
end

include("core/core.jl")
include("yaml/yaml.jl")
include("addons/addons.jl")

function validate(toplevel_config_file::String)
    toplevel_config_file = abspath(toplevel_config_file)
    model_path = dirname(toplevel_config_file)

    # TODO: Catch `high_performance` here manually and skip validation
    valid = true

    valid &= _validate_raw_yaml(toplevel_config_file)

    # Try to continue with an "empty" configuration if the top-level config is invalid.
    _top_level_config = valid ? YAML.load_file(toplevel_config_file; dicttype=Dict{String, Any}) : Dict{String, Any}()

    files_to_validate = []

    # Add the specified parameters file (if one exists).
    if haskey(_top_level_config, "parameters") && (_top_level_config["parameters"] isa String)
        push!(files_to_validate, abspath(model_path, _top_level_config["parameters"]))
    end

    # Extract configured paths or defaults.
    paths = get(_top_level_config, "paths", Dict{String, Any}())
    folders = [
        replace(get(paths, "files", "files"), '\\' => '/'),
        replace(get(paths, "templates", "templates"), '\\' => '/'),
        replace(get(paths, "components", "components"), '\\' => '/'),
        replace(get(paths, "addons", "addons"), '\\' => '/'),
    ]

    # Find all relevant files in the specified folders.
    for entry in folders
        folder = abspath(model_path, entry)
        for (root, _, files) in walkdir(folder)
            for file in files
                if endswith(file, ".iesopt.template.yaml") || endswith(file, ".jl")
                    push!(files_to_validate, abspath(root, file))
                end

                # TODO: Detect CSV component files, and implement validation.
            end
        end
    end

    # Validate all found files.
    for filename in files_to_validate
        if endswith(filename, ".jl")
            valid &= _validate_addon(filename)
        else
            valid &= _validate_raw_yaml(filename)
        end
    end

    return _vassert(valid, "Encountered error(s) while validating model description"; config=toplevel_config_file)
end

# TODO: Collection of old comments regarding points to validate, see below.

# if config.aggregate
#     if haskey(config, "weights") || haskey(config, "offset") || haskey(config, "names")
#         @error "Snapshot aggregation only supports setting `count`"
#     end
# end

# config/opt: get(config, "multiobjective", nothing) only with "MO/mo" in config

# if isempty(config)
#     @warn "No result section found in model config; consider specifying `results` before running the model"
# end

# if !haskey(data, "config")
#     @error "Missing `config` entry"
#     return false
# end

# parameters = pop!(data, "parameters", Dict())
# if parameters isa String
#     if !endswith(parameters, ".iesopt.param.yaml")
#         @error "Wrong file supplied for global parameters, should end in `.iesopt.param.yaml" filename = parameters
#     end
# end

# adding "weight" to snapshots should produce an error => "weights" is the correct key, all "unused" keys should trigger a warning
