function _validate_raw_yaml_iesopt_param(filename::String)
    valid = true

    content = Dict{String, Any}()
    try
        merge!(content, YAML.load_file(filename; dicttype=Dict{String, Any}))
    catch
        return _vassert(false, "Could not load YAML file"; filename=filename)
    end

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; filename=filename, exception=exception)
    end

    return valid
end
