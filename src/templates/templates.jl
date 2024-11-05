
include("utils.jl")

include("functions/functions.jl")
include("load.jl")
include("parse.jl")

@recompile_invalidations begin
    function Base.show(io::IO, template::CoreTemplate)
        info = _analyse(template)

        beautify(value::Any) = value
        beautify(value::Vector) =
            isempty(value) ? "-" :
            (length(value) <= 4 ? join(value, ", ") : "$(value[1]), $(value[2]), ..., $(value[end])")

        str_show = ":: IESopt.Template ::"

        ks = collect(keys(info))
        for k in ks[1:(end - 1)]
            v = info[k]
            (k == "docs") && (v = collect(keys(info[k])))
            (k == "parameters") && (v = [p for p in keys(info[k]) if !startswith(p, "_")])
            str_show *= "\n├ $k: $(beautify(v))"
        end
        k = ks[end]
        v = (k in ["docs", "parameters"]) ? collect(keys(info[k])) : info[k]
        str_show *= "\n└ $k: $(beautify(v))"

        return print(io, str_show)
    end
end

function _analyse(template::CoreTemplate)
    old_status = template._status[]
    template = _require_template(template.model, template.name)
    template._status[] = old_status

    internal = _is_container(template) ? values(template.yaml["components"]) : [template.yaml["component"]]
    child_types = sort!(collect(Set(comp["type"] for comp in internal)))::Vector{String}
    instances = get(_iesopt(template.model).model.tags, template.name, String[])

    docs = get(template.yaml, "docs", Dict{String, Any}())
    isempty(docs) && @warn "Template is missing `docs` entry" template = template.name

    return OrderedDict(
        "type" => _is_container(template) ? template.name : "$(template.name) <: $(child_types[1])",
        "instances" => instances,
        "docs" => docs,
        "parameters" => get(template.yaml, "parameters", Dict{String, Any}()),
        "child types" => child_types,
        "functions" => collect(keys(get(template.yaml, "functions", Dict{String, Any}()))),
    )
end

function create_docs(template::CoreTemplate)
    info = analyse(template)
    # TODO
    return info.docs
end
