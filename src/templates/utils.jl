function _get_parameter_safe(p::String, parameters::Dict{String, Any}, default::Any=nothing)
    haskey(parameters, p) || @critical "Trying to access (`get`) undefined parameter in `CoreTemplate`" parameter = p
    return isnothing(default) ? parameters[p] : something(parameters[p], default)
end

function _set_parameter_safe(p::String, v::Any, parameters::Dict{String, Any})
    haskey(parameters, p) || @critical "Trying to access (`set`) undefined parameter in `CoreTemplate`" parameter = p
    parameters[p] = v
    return nothing
end

function _get_timeseries_safe(p_or_cf::String, parameters::Dict{String, Any}, model::JuMP.Model)
    if !occursin("@", p_or_cf)
        p_or_cf = _get_parameter_safe(p_or_cf, parameters)::String
    end

    # Now we know, that `p_or_cf` is a "col@file" selector string.
    column, file = string.(split(p_or_cf, "@"))

    return _getfromcsv(model, file, column)
end

function _set_timeseries_safe(p_or_cf::String, v::Any, parameters::Dict{String, Any}, model::JuMP.Model)
    if !occursin("@", p_or_cf)
        p_or_cf = _get_parameter_safe(p_or_cf, parameters)::String
    end

    # Now we know, that `p_or_cf` is a "col@file" selector string.
    column, file = string.(split(p_or_cf, "@"))

    # Check if this file exists.
    if haskey(internal(model).input.files, file)
        # This works for overwriting existing columns, as well as adding new ones.
        internal(model).input.files[file][!, column] .= v
    else
        internal(model).input.files[file] = DataFrames.DataFrame(column => v)
    end

    return nothing
end

_is_template(filename::String) = endswith(filename, ".iesopt.template.yaml")
_get_template_name(filename::String) = string(rsplit(basename(filename), "."; limit=4)[1])

_get_type(template::CoreTemplate) = template.type[]::Symbol

function _set_type!(template::CoreTemplate, t::Symbol)
    template.type[] = t
    return nothing
end

_is_component(template::CoreTemplate) = _get_type(template) == :component
_is_container(template::CoreTemplate) = _get_type(template) == :container
