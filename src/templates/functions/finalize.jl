function _build_template_function_finalize(template::CoreTemplate)
    if !haskey(template.yaml, "functions") || !haskey(template.yaml["functions"], "finalize")
        template.functions[:finalize] = (::JuMP.Model, ::String, ::Dict{String, Any}) -> nothing
        return nothing
    end

    # Get code from "finalize" and remove trailing newline.
    code = chomp(template.yaml["functions"]["finalize"])

    # Parse the code into an expression.
    code_ex = Meta.parse("""begin\n$(code)\nend"""; filename="$(template.name).iesopt.template.yaml")

    # Convert into a proper function.
    template.functions[:finalize] = @RuntimeGeneratedFunction(
        :(
            function (__model__::JuMP.Model, __component__::String, __parameters__::Dict{String, Any})
                __template_name__ = $(template).name
                __items__ = _iesopt(__model__).results._templates[__component__].items

                this = (
                    get = (s, args...) -> _get_parameter_safe(s, __parameters__, args...),
                    get_ts = (s::String) -> _get_timeseries_safe(s, __parameters__, __model__),
                    self = _get_parameter_safe("self", __parameters__, nothing),
                    access = (sub::String) -> sub == "self" ? get_component(__model__, __component__) : get_component(__model__, "$(__component__).$(sub)"),
                    model = Utilities.ModelWrapper(__model__),
                )

                try
                    $code_ex
                catch e
                    template = __template_name__
                    component = __component__
                    @error "Error while finalizing component" error = string(e) template component
                    rethrow(e)
                end
                return nothing
            end
        )
    )

    return nothing
end
