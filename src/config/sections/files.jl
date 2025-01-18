function _prepare_config_files!(model::JuMP.Model)
    data = get(internal(model).input._tl_yaml["config"], "files", Dict{String, String}())

    @config(model, files) =
        Dict{String, String}(k => normpath(replace(v, '\\' => '/')) for (k, v) in data if k != "_csv_config")

    if any(startswith(k, "_") for k in keys(@config(model, files)))
        @error "Please refrain from using file names (in the `files` section) starting with an underscore"
    end

    _csv_config = (
        if haskey(data, "_csv_config")
            @info "Modifying CSV loading configuration; this feature is experimental"
            data["_csv_config"]
        else
            Dict{String, Any}()
        end
    )
    @config(model, files._csv_config) = Dict{String, Any}(
        "comment" => get(_csv_config, "comment", nothing),
        "delim" => only(get(_csv_config, "delim", ",")),
        "decimal" => only(get(_csv_config, "decimal", ".")),
    )

    return nothing
end
