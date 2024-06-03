function _validate_raw_yaml_iesopt_template(filename::String)
    valid = true

    content = Dict{String, Any}()
    try
        merge!(content, YAML.load_file(filename; dicttype=Dict{String, Any}))
    catch
        return _vassert(false, "Could not load YAML file"; filename=filename)
    end

    try
        # TODO: Only allowed: "parameters", "components", "component".

        valid &= _vassert(
            haskey(content, "components") || haskey(content, "component"),
            "Template requires either `components` or `component`";
            filename=filename,
        )

        valid &= _vassert(
            !(haskey(content, "components") && haskey(content, "component")),
            "Template requires either `components` or `component`, but not both at the same time";
            filename=filename,
        )

        if haskey(content, "components")
            for (k, v) in content["components"]
                valid &= _validate_component(k, v)
            end
        end

        if haskey(content, "component")
            template_name = split(splitpath(filename)[end], ".")[1]
            valid &= _validate_component("_anonymouscomponent_$(template_name)", content["component"])
        end

        # TODO: Validate other things.
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; filename=filename, exception=exception)
    end

    return valid
end
