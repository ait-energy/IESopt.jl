"""
    overview(file::String)

Extracts the most important information from an IESopt model file, and returns it as a dictionary.
"""
function overview(file::String)
    if endswith(file, ".iesopt.yaml")
        @critical "Only single-file IESopt models are supported by `overview` (can be created using `pack(...)`" file
    elseif !endswith(file, ".iesopt")
        @critical "Unsupported file format" file
    end

    @debug "Unpacking IESopt model"
    info = unpack(file)
    root_path = dirname(info["config"])

    config = YAML.load_file(info["config"]; dicttype=OrderedDict{String, Any})

    summary = Dict{String, Any}(
        "version" => info["version"],
        "path" => root_path,
        "tlc_filename" => info["config"],
        "files" => info["files"],
    )

    if haskey(config, "parameters")
        if config["parameters"] isa String
            summary["parameter_type"] = "file: $(config["parameters"])"
            summary["parameter_value"] =
                YAML.load_file(normpath(root_path, config["parameters"]); dicttype=Dict{String, Any})
        elseif config["parameters"] isa Dict
            summary["parameter_type"] = "dict"
            summary["parameter_value"] = config["parameters"]
        else
            summary["parameter_type"] = "unknown"
            summary["parameter_value"] = Dict()
        end
    else
        summary["parameter_type"] = "empty"
        summary["parameter_value"] = Dict()
    end

    summary["config"] = Dict{String, Any}()
    for entry in ["name", "optimization", "files", "paths", "results"]
        summary["config"][entry] = get(config["config"], entry, Dict())
    end

    summary["carriers"] = get(config, "carriers", Dict())

    return summary
end
