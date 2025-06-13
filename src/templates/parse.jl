function _parse_noncore_component!(
    model::JuMP.Model,
    type::String,
    configuration::Dict{String, Any},
    cname::String,
)::Dict{String, Any}
    # Get template and file.
    template = internal(model).input.noncore[:templates][type]
    parameters = deepcopy(get(template.yaml, "parameters", Dict{String, Any}()))

    # Parse parameters from configuration.
    for (param, value) in parameters
        parameters[param] = pop!(configuration, param, value)
    end

    # Remove parameters prefixed with "_" since those should not be considered.
    delete!.(Ref(configuration), [k for k in keys(configuration) if startswith(k, "_")])

    # Add "name" replacement parameter(s).
    level = cname
    accessor = "."
    while true
        parameters[accessor] = level
        !occursin(".", level) && break
        level, _ = rsplit(level, "."; limit=2)
        accessor *= "."
    end
    if haskey(parameters, "self")
        @warn "Use of `<self>` as parameter detected; this can lead to confusion and should be avoided" component =
            cname
    else
        parameters["self"] = parameters["."]
    end
    if haskey(parameters, "..")
        if haskey(parameters, "parent")
            @warn "Use of `<parent>` as parameter detected; this can lead to confusion and should be avoided" component =
                cname
        else
            parameters["parent"] = parameters[".."]
        end
    end
    if haskey(parameters, "name")
        @warn "Use of `<name>` as parameter detected; this can lead to confusion and should be avoided" component =
            cname
    else
        parameters["name"] = split(cname, ".")[end]
    end

    # Add global parameters
    for (k, v) in internal(model).input.parameters
        if haskey(parameters, k)
            @warn "Ambiguous parameter in component and global specification; using local value" component = cname parameter =
                k
            continue
        end
        parameters[k] = v
    end

    # Write the final version of parameters into the Virtual.
    virtual = internal(model).model.components[cname]
    merge!(virtual._parameters, parameters)

    if haskey(template.yaml, "functions")
        @warn "It is highly recommended NOT to use `functions` in single component templates that just \"rename\" another template" template =
            template.name maxlog = 1

        # Validate and then prepare.
        template.functions[:validate](virtual) || @critical "Template validation failed" component = cname
        template.functions[:prepare](virtual)

        # Add an entry for finalization.
        push!(virtual._finalizers, template.functions[:finalize])
    end

    # Convert data types that do not "render" well to strings using JSON. (SEE BELOW)
    # Example:
    # `Dict{String, Any}("electricity" => 1)` will just be rendered as `"Dict{String, Any}("electricity" => 1)"`,
    # which then messes with replacement in the YAML parsing.

    # This would result in modifying the original `parameters` dictionary, which is not desired.
    # Therefore, we keep a copy (not a deep copy!) and modify that, only duplicating potential json-ed items.
    parameters = copy(virtual._parameters)

    for (k, v) in parameters
        (v isa Dict) || continue
        parameters[k] = JSON.json(v)
    end

    # Construct the parsed core component with all parameter replacements.
    replacements = Regex(join(["<$k>" for k in keys(parameters)], "|")::String)
    if length(parameters) == 0
        comp = template.yaml["component"]
    else
        comp = Dict{String, Any}()
        for (k, v) in template.yaml["component"]
            _new_component_str = replace(
                replace(YAML.write(v), replacements => p -> parameters[p[2:(end - 1)]]),
                "\"" => "",  # this is necessary to prevent `Number`s being enclosed with "", ending up as `String`
                "nothing" => "null", # this is necessary to properly preserve "null" (as nothing)
            )::String
            if occursin("<", _new_component_str)
                param_begin = (findfirst("<", _new_component_str)::UnitRange{Int64})[1]
                param_end = (findnext(">", _new_component_str, param_begin)::UnitRange{Int64})[1]
                parameter = _new_component_str[param_begin:param_end]
                @critical "Parameter placeholder not replaced" component = cname parameter
            end
            comp[k] = YAML.load(_new_component_str; dicttype=Dict{String, Any})
        end
    end

    # Add potential files to the overall file list.
    if haskey(template.yaml, "files")
        for file in template.yaml["files"]
            filedescr = replace(file[1], replacements => p -> parameters[p[2:(end - 1)]])
            haskey(internal(model).input.files, filedescr) && continue

            filename = replace(file[2], replacements => p -> parameters[p[2:(end - 1)]])
            internal(model).input.files[filedescr] = _getfile(model, filename)
        end
    end

    # Report possibly wrongly accessed attributes.
    for (attr, _) in configuration
        @error "Non exported component attribute accessed" type = type attribute = attr
    end

    # TODO: allow "Set"s in single components too!

    return comp
end

function _parse_container!(
    model::JuMP.Model,
    description::Dict{String, Any},
    name::String,
    type::String,
)::Vector{String}
    # Get template and file.
    template = internal(model).input.noncore[:templates][type]
    parameters = copy(get(template.yaml, "parameters", Dict{String, Any}()))

    # Get top-level configuration.
    configuration = description[name]

    # Remove parameters prefixed with "_" since those should not be considered.
    delete!.(Ref(configuration), [k for k in keys(configuration) if startswith(k, "_")])

    # Parse parameters from configuration.
    for (param, value) in parameters
        parameters[param] = pop!(configuration, param, value)
    end

    # Report possibly wrongly accessed attributes.
    for (attr, _) in configuration
        @warn "Non exported component attribute accessed" name = name attribute = attr maxlog = 1
    end

    # Add "name" replacement parameter(s).
    level = name
    accessor = "."
    while true
        parameters[accessor] = level
        !occursin(".", level) && break
        level, _ = rsplit(level, "."; limit=2)
        accessor *= "."
    end
    if haskey(parameters, "self")
        @warn "Use of `<self>` as parameter detected; this can lead to confusion and should be avoided" component = name
    else
        parameters["self"] = parameters["."]
    end
    if haskey(parameters, "..")
        if haskey(parameters, "parent")
            @warn "Use of `<parent>` as parameter detected; this can lead to confusion and should be avoided" component =
                name
        else
            parameters["parent"] = parameters[".."]
        end
    end
    if haskey(parameters, "name")
        @warn "Use of `<name>` as parameter detected; this can lead to confusion and should be avoided" component = name
    else
        parameters["name"] = split(name, ".")[end]
    end

    # Add global parameters
    for (k, v) in internal(model).input.parameters
        if haskey(parameters, k)
            @warn "Ambiguous parameter in component and global specification; using local value" component = name parameter =
                k
            continue
        end
        parameters[k] = v
    end

    # Write the final version of parameters into the Virtual.
    virtual = internal(model).model.components[name]
    merge!(virtual._parameters, parameters)

    # Validate and then prepare.
    template.functions[:validate](virtual) || @critical "Template validation failed" component = name
    template.functions[:prepare](virtual)

    # Add an entry for finalization.
    push!(virtual._finalizers, template.functions[:finalize])

    # Convert data types that do not "render" well to strings using JSON. (SEE BELOW)
    # Example:
    # `Dict{String, Any}("electricity" => 1)` will just be rendered as `"Dict{String, Any}("electricity" => 1)"`,
    # which then messes with replacement in the YAML parsing.

    # This would result in modifying the original `parameters` dictionary, which is not desired.
    # Therefore, we keep a copy (not a deep copy!) and modify that, only duplicating potential json-ed items.
    parameters = copy(virtual._parameters)

    for (k, v) in parameters
        (v isa Dict) || continue
        parameters[k] = JSON.json(v)
    end

    # Construct the parsed container with all parameter replacements.
    replacements = Regex(join(["<$k>" for k in keys(parameters)], "|")::String)
    _new_components_str = replace(
        replace(YAML.write(template.yaml["components"]), replacements => p -> parameters[p[2:(end - 1)]]),
        "\"" => "",  # this is necessary to prevent `Number`s being enclosed with "", ending up as `String`
        "nothing" => "null", # this is necessary to properly preserve "null" (as nothing)
    )::String
    if occursin("<", _new_components_str)
        param_begin = (findfirst("<", _new_components_str)::UnitRange{Int64})[1]
        param_end = (findnext(">", _new_components_str, param_begin)::UnitRange{Int64})[1]
        parameter = _new_components_str[param_begin:param_end]
        @critical "Parameter placeholder not replaced" component = name parameter
    end
    components = YAML.load(_new_components_str; dicttype=Dict{String, Any})

    # Add potential files to the overall file list.
    if haskey(template.yaml, "files")
        for file in template.yaml["files"]
            filedescr = replace(file[1], replacements => p -> parameters[p[2:(end - 1)]])
            haskey(internal(model).input.files, filedescr) && continue
            filename = replace(file[2], replacements => p -> parameters[p[2:(end - 1)]])
            internal(model).input.files[filedescr] = _getfile(model, filename)
        end
    end

    # Resolve potentially existing CSV components in the template
    csv_components = Dict{String, Any}()
    _parse_components_csv!(model, template.yaml, csv_components; path=template.path)

    # Ensure proper parameter replacement for all loaded CSV components
    csv_components = YAML.load(
        replace(
            replace(YAML.write(csv_components), replacements => p -> parameters[p[2:(end - 1)]]),
            "\"" => "",  # this is necessary to prevent `Number`s being enclosed with "", ending up as `String`
            "nothing" => "null", # this is necessary to properly preserve "null" (as nothing)
        );
        dicttype=Dict{String, Any},
    )

    # Add all parts of the container to the description with "."-updated names.
    new_components = []
    for (cname, cdesc) in components
        if cdesc["type"] == "Set"
            # Check if the Set is disabled.
            if _parse_bool(model, pop!(cdesc, "disabled", false)) || !_parse_bool(model, pop!(cdesc, "enabled", true))
                continue
            end

            if haskey(cdesc, "components")
                # Add all components of the set.
                for (set_cname, set_cdesc) in cdesc["components"]
                    _fullname = "$name.$set_cname"
                    if haskey(description, _fullname)
                        @critical "Resolving a set resulted in non-unique components" name set = cname component =
                            set_cname
                    end
                    description[_fullname] = set_cdesc
                    push!(new_components, _fullname)
                end
            elseif haskey(cdesc, "component")
                # Just add the single component.
                if length(new_components) > 0
                    @critical "Single component Sets can not produce new components" name set = cname
                end
                @warn "Single component Sets are performing self-replacement; if you do not understand or expect this warning, there is most likely a misconfiguration happening" maxlog =
                    1 name set = cname
                description[name] = cdesc["component"]
                return [name]
            else
                @critical "Set is missing `components` and `component` key" name set = cname
            end
        else
            if haskey(description, "$name.$cname")
                @critical "Resolving a container resulted in non-unique components" name component = cname
            end
            description["$name.$cname"] = cdesc
            push!(new_components, "$name.$cname")
        end
    end

    # Add all parts of the CSV to the description with "."-updated names.
    for (cname, cdesc) in csv_components
        description["$name.$cname"] = cdesc
        push!(new_components, "$name.$cname")
    end

    # Remove the original container description.
    delete!(description, name)

    return new_components
end

function _parse_noncore!(model::JuMP.Model, description::Dict{String, Any}, cname::String)::Vector{String}
    # Check if this component or container is disabled. For a component we can immediately "skip" it here, for a
    # container, disabling will also disable every contained component, therefore we can also "skip" it completely.
    if _parse_bool(model, pop!(description[cname], "disabled", false)) ||
       !_parse_bool(model, pop!(description[cname], "enabled", true))
        # We delete the element (component or container) from the model.
        delete!(description, cname)
        # Returning `[]` makes sure that no new components are added to the flattened model (see `_flatten_model!`).
        return String[]
    end

    type = pop!(description[cname], "type")
    template = _require_template(model, type)

    # Extract tags, if there are any.
    if "tags" in keys(description[cname])
        model_tags = internal(model).model.tags
        tags = pop!(description[cname], "tags")
        tags = tags isa String ? [tags] : tags
        for tag in tags
            if !haskey(model_tags, tag)
                model_tags[tag] = Vector{String}()
            end
            push!(model_tags[tag], cname)
        end
    end

    # Remember its name and type properly, before that is lost due to flattening, by constructing a Virtual.
    internal(model).model.components[cname] = Virtual(;
        model,
        name=cname,
        type,
        _template=template,
        config=pop!(description[cname], "config", Dict{String, Any}()),
    )

    # Properly tag the new Virtual.
    !haskey(internal(model).model.tags, type) && (internal(model).model.tags[type] = Vector{String}())
    push!(internal(model).model.tags[type], cname)

    # if !haskey(internal(model).input.noncore[:templates], type)
    #     valid_templates = [
    #         path for
    #         path in internal(model).input.noncore[:paths] if isfile(normpath(path, string(type, ".iesopt.template.yaml")))
    #     ]
    #     (length(valid_templates) == 0) && error("Type template <$type.iesopt.template.yaml> could not be found")
    #     (length(valid_templates) != 1) && error("Type template <$type.iesopt.template.yaml> is ambiguous")

    #     template_path = valid_templates[1]
    #     template_file = normpath(template_path, string(type, ".iesopt.template.yaml"))

    #     internal(model).input.noncore[:templates][type] = YAML.load_file(template_file; dicttype=Dict{String, Any})
    #     internal(model).input.noncore[:templates][type]["path"] = template_path
    #     @info "Encountered non-core component" type = type template = template_file
    # end

    # is_container = haskey(internal(model).input.noncore[:templates][type], "components")
    # is_component = haskey(internal(model).input.noncore[:templates][type], "component")

    if _is_component(template)
        description[cname] = _parse_noncore_component!(model, type, description[cname], cname)
        return [cname]
    elseif _is_container(template)
        return _parse_container!(model, description, cname, type)
    end

    @critical "Core Template seems to be neither `component` nor `container`, check specification of `components: ...` and/or `component: ...` entry" name =
        type

    return String[]
end
