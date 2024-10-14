function _build_template_function_prepare(template::CoreTemplate)
    if !haskey(template.yaml, "functions") || !haskey(template.yaml["functions"], "prepare")
        template.functions[:prepare] = (::Dict{String, Any}, ::String) -> nothing
        return nothing
    end

    # Get code from "prepare" and remove trailing newline.
    code = chomp(template.yaml["functions"]["prepare"])

    # Parse the code into an expression.
    code_ex = Meta.parse("""begin\n$(code)\nend"""; filename="$(template.name).iesopt.template.yaml")

    # Convert into a proper function.
    template.functions[:prepare] = @RuntimeGeneratedFunction(
        :(function (__parameters__::Dict{String, Any}, __component__::String)
            __MODEL__ = Utilities.ModelWrapper($(template).model)
            __template_name__ = $(template).name

            this = (
                get = (s, args...) -> _get_parameter_safe(s, __parameters__, args...),
                set = (p::String, v::Any) -> _set_parameter_safe(p, v, __parameters__),
                get_ts = (s::String) -> _get_timeseries_safe(s, __parameters__, __MODEL__.iesopt_model),
                set_ts = (s::String, v::Any) -> _set_timeseries_safe(s, v, __parameters__, __MODEL__.iesopt_model),
                self = _get_parameter_safe("self", __parameters__, nothing),
                model = __MODEL__,
            )

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
