include("md/markdown.jl")

"""
    docify(model::JuMP.Model, filename::String; format::String="markdown")

Document an IESopt model in the given format. Experimental feature, use with caution. Some formulations are currently
not (or only partially) converted.

# Arguments
- `model::JuMP.Model`: The model to document.
- `filename::String`: The filename to save the documentation.
- `format::String`: The format to save the documentation in. Default is "markdown".
"""
function docify(model::JuMP.Model, filename::String; format::String="markdown")
    filename = abspath(filename)

    if format == "markdown"
        _docify_to_markdown(model, filename)
        @info "[docify] Model documentation written to file" filename
    else
        @critical "[docify] Unsupported format: $format"
    end

    return nothing
end
