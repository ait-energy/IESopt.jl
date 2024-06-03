function _build_template_function_prepare(template::CoreTemplate)
    if !haskey(template.yaml, "functions") || !haskey(template.yaml["functions"], "prepare")
        template.functions[:prepare] = (::Dict{String, Any}, ::String) -> nothing
        return nothing
    end

    # Get code from "prepare" and remove trailing newline.
    code = chomp(template.yaml["functions"]["prepare"])

    # Replace the `get` function (that would otherwise conflict with Julia's `get` function).
    code = replace(code, r"""get\("([^"]+)"\)""" => s"""_get_parameter_safe("\1", __parameters__)""")

    # Parse the code into an expression.
    code_ex = Meta.parse("""begin\n$(code)\nend"""; filename="$(template.name).iesopt.template.yaml")

    # Convert into a proper function.
    template.functions[:prepare] = @RuntimeGeneratedFunction(
        :(function (__parameters__::Dict{String, Any}, __component__::String)
            MODEL = Utilities.ModelWrapper($(template).model)
            __template_name__ = $(template).name

            set(p::String, v::Any) = _set_parameter_safe(p, v, __parameters__)
            get_ts(s::String) = _get_timeseries_safe(s, __parameters__, MODEL.model)
            set_ts(s::String, v::Any) = _set_timeseries_safe(s, v, __parameters__, MODEL.model)

            try
                $code_ex
            catch e
                template = __template_name__
                component = __component__
                @error "Error while preparing component" error = string(e) template component
                rethrow(e)
            end
            return nothing
        end)
    )

    return nothing
end
