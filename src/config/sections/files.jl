function _prepare_config_files!(model::JuMP.Model)
    data = get(internal(model).input._tl_yaml["config"], "files", Dict{String, String}())

    @config(model, files) = Dict{String, String}(k => normpath(replace(v, '\\' => '/')) for (k, v) in data)

    return nothing
end
