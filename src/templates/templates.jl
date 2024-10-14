"""
    CoreTemplate

A struct to represent an IESopt.jl "Core Template".
"""
@kwdef struct CoreTemplate
    model::JuMP.Model
    name::String
    path::String
    raw::String
    yaml::Dict{String, Any} = Dict{String, Any}()

    """A dictionary of functions that can be called by the template, options are `:validate`, `:prepare`, `:finalize`."""
    functions::Dict{Symbol, Function} = Dict{Symbol, Function}()

    """Type of this `CoreTemplate`: `:container` (if `"components"` exists), `:component` (if `"component"` exists)."""
    type::Ref{Symbol} = Ref(:none)

    _status::Ref{Symbol}
end

function _get_parameter_safe(p::String, parameters::Dict{String, Any}, default::Any = nothing)
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
    if haskey(_iesopt(model).input.files, file)
        # This works for overwriting existing columns, as well as adding new ones.
        _iesopt(model).input.files[file][!, column] .= v
    else
        _iesopt(model).input.files[file] = DataFrames.DataFrame(column => v)
    end

    return nothing
end

include("functions/functions.jl")
include("load.jl")
include("parse.jl")

_is_template(filename::String) = endswith(filename, ".iesopt.template.yaml")
_get_template_name(filename::String) = string(rsplit(basename(filename), "."; limit=4)[1])
_is_component(template::CoreTemplate) = template.type[] == :component
_is_container(template::CoreTemplate) = template.type[] == :container

function Base.show(io::IO, template::CoreTemplate)
    str_show = "IESopt.CoreTemplate: $(template.name)"
    return print(io, str_show)
end

function analyse(template::CoreTemplate)
    old_status = template._status[]
    template = _require_template(template.model, template.name)
    template._status[] = old_status

    child_types::Vector{String} = sort!(collect(Set(if haskey(template.yaml, "component")
        [template.yaml["component"]["type"]]
    else
        [v["type"] for v in values(template.yaml["components"])]
    end)))

    child_templates = [t for t in child_types if t ∉ ["Connection", "Decision", "Node", "Profile", "Unit"]]
    child_corecomponents = [t for t in child_types if t in ["Connection", "Decision", "Node", "Profile", "Unit"]]

    docs = ""
    for line in eachline(IOBuffer(template.raw))
        startswith(line, "#") || break
        length(line) >= 3 || continue
        docs = "$(docs)\n$(line[3:end])"
    end

    if isempty(docs)
        @warn "Encountered empty docstring for `CoreTemplate`" template = template.name
    else
        docs = docs[2:end]  # remove the leading `\n`
        startswith(docs, "# ") ||
            @warn "`CoreTemplate` docstring should start with main header (`# Your Title`)" template = template.name
        for section in ["Parameters", "Components", "Usage"]
            occursin("## $(section)\n", docs) ||
                @warn "`CoreTemplate` is missing mandatory section in docstring" template = template.name section
        end
    end

    return (
        name=template.name,
        was_prepared=old_status == :yaml,
        docs=Markdown.parse(docs),
        functions=keys(get(template.yaml, "functions", Dict{String, Any}())),
        parameters=get(template.yaml, "parameters", Dict{String, Any}()),
        child_templates=child_templates,
        child_corecomponents=child_corecomponents,
    )
end

function create_docs(template::CoreTemplate)
    info = analyse(template)
    # TODO
    return info.docs
end
