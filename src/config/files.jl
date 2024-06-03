struct _ConfigFiles
    entries::Dict{String, String}
end

function _ConfigFiles(config::Dict{String, Any}, paths::_ConfigPaths)
    return _ConfigFiles(Dict(k => normpath(v) for (k, v) in config))
end
