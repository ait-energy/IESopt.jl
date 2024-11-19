include("iesopt.jl")
include("iesopt.template.jl")
include("iesopt.param.jl")

function _validate_raw_yaml(filename::String)
    _vassert(isfile(filename), "File does not exist"; filename=filename) || return false

    if endswith(filename, ".iesopt.yaml")
        return _validate_raw_yamlinternal(filename)
    elseif endswith(filename, ".iesopt.template.yaml")
        return _validate_raw_yaml_iesopt_template(filename)
    elseif endswith(filename, ".iesopt.param.yaml")
        return _validate_raw_yaml_iesopt_param(filename)
    end

    return _vassert(false, "File extension not recognized"; filename=filename)
end
