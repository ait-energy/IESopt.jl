struct _ConfigPaths
    main::String

    files::String
    results::String
    templates::String
    components::String
    addons::String
end

function _ConfigPaths(config::Dict{String, Any}, model_path::String, names::_ConfigNames)
    model_path = normpath(replace(model_path, '\\' => '/'))

    return _ConfigPaths(
        model_path,
        normpath(model_path, replace(get(config, "files", "files"), '\\' => '/')),
        normpath(model_path, replace(get(config, "results", "out"), '\\' => '/'), names.model),
        normpath(model_path, replace(get(config, "templates", "templates"), '\\' => '/')),
        normpath(model_path, replace(get(config, "components", "components"), '\\' => '/')),
        normpath(model_path, replace(get(config, "addons", "addons"), '\\' => '/')),
    )
end
