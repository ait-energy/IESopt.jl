function _prepare_config_paths!(model::JuMP.Model)
    clean(path::String) = replace(path, '\\' => '/')

    data = get(internal(model).input._tl_yaml["config"], "paths", Dict{String, Any}())
    model_path = clean(model.ext[:_iesopt_wd])
    model_name = @config(model, general.name.model, String)

    @config(model, paths) = Dict{String, Dict{String, String}}()

    @config(model, paths.main) = model_path
    @config(model, paths.files) = normpath(model_path, clean(get(data, "files", "files")))
    @config(model, paths.results) = normpath(model_path, clean(get(data, "results", "out")), model_name)
    @config(model, paths.templates) = normpath(model_path, clean(get(data, "templates", "templates")))
    @config(model, paths.components) = normpath(model_path, clean(get(data, "components", "components")))
    @config(model, paths.addons) = normpath(model_path, clean(get(data, "addons", "addons")))

    # ATTENTION: When modifying this, ensure it matches the defaults, etc., used in `parser.jl`.
    @config(model, paths.parameters) = normpath(model_path, clean(get(data, "parameters", "./")))

    return nothing
end
