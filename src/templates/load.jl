function _load_template(model::JuMP.Model, filename::String; read_file::Bool=false)
    name = _get_template_name(filename)
    read_file && @info "Loading template file" name

    template = CoreTemplate(;
        model=model,
        name=name,
        path=dirname(filename),
        raw=read_file ? read(filename, String) : "",
        _status=read_file ? Ref(:raw) : Ref(:empty),
    )

    _iesopt(model).input.noncore[:templates][name] = template
    return template
end

_load_template(template::CoreTemplate) =
    _load_template(template.model, normpath(template.path, "$(template.name).iesopt.template.yaml"); read_file=true)

function _load_template_yaml!(template::CoreTemplate)
    merge!(template.yaml, YAML.load(template.raw; dicttype=Dict{String, Any}))
    template._status[] = :yaml

    has_components = haskey(template.yaml, "components")
    has_component = haskey(template.yaml, "component")

    if has_components && !has_component
        template.type[] = :container
    elseif !has_components && has_component
        template.type[] = :component
    else
        @critical "Template type could not be determined" template = template.name
    end

    # Build all registered functions for this template.
    _build_template_function_prepare(template)
    _build_template_function_validate(template)
    _build_template_function_finalize(template)

    return nothing
end

function _scan_all_templates(model::JuMP.Model)
    # Prepare the templates dictionary.
    _iesopt(model).input.noncore[:templates] = Dict{String, CoreTemplate}()

    # Scan for templates in template folder and core internal templates.
    all_template_files = Set{String}()
    for dir in [_iesopt_config(model).paths.templates, _PATHS[:templates]]
        for (root, _, files) in walkdir(dir)
            isempty(files) && continue
            for filename in files
                _is_template(filename) || continue
                (filename in all_template_files) && @critical "Duplicate file found in template folder" root filename
                push!(all_template_files, normpath(root, filename))
            end
        end
    end

    # Load all templates, without actually reading in the files.
    for template_file in all_template_files
        _load_template(model, template_file)
    end

    @info "Finished scanning templates" count = length(_iesopt(model).input.noncore[:templates])

    # valid_templates = [
    #     path for
    #     path in _iesopt(model).input.noncore[:paths] if isfile(normpath(path, string(type, ".iesopt.template.yaml")))
    # ]
    # (length(valid_templates) == 0) && error("Type template <$type.iesopt.template.yaml> could not be found")
    # (length(valid_templates) != 1) && error("Type template <$type.iesopt.template.yaml> is ambiguous")

    # template_path = valid_templates[1]
    # template_file = normpath(template_path, string(type, ".iesopt.template.yaml"))

    # _iesopt(model).input.noncore[:templates][type] = YAML.load_file(template_file; dicttype=Dict{String, Any})
    # _iesopt(model).input.noncore[:templates][type]["path"] = template_path
    # @info "Encountered non-core component" type = type template = template_file
end

function _require_template(model::JuMP.Model, name::String)
    haskey(_iesopt(model).input.noncore[:templates], name) || @critical "`CoreTemplate` not found" name
    template = _iesopt(model).input.noncore[:templates][name]

    if template._status[] == :empty
        template = _load_template(template)
    end

    (template._status[] == :raw) && _load_template_yaml!(template)

    return template
end
