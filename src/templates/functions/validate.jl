"""
    @check

Check whether the passed expression passes an `ArgCheck.@check`, especially helpful to validate a Template's parameters.

# Example

A `validate` section added to a Template can make use of the `@check` macro to validate the parameters passed to the
template. The macro will properly raise a descriptive error if the condition is not met.

```yaml
parameters:
  p: null

functions:
  validate: |
    @check parameters["p"] isa Number
    @check parameters["p"] > 0
```

See ["Template Validation"](@ref manual_templates_validation) in the documentation for more information.

!!! warning "Usage outside of Core Template validation"
    This requires `__component__` to be set to some `String` outside of calling the macro, since it accesses this to
    construct a proper error message.
"""
macro check(expr)
    return esc(
        quote
            try
                $ArgCheck.@check $expr
            catch e
                if isa(e, $ArgCheck.CheckError)
                    local cname = $(:__component__)
                    local message = replace(e.msg, "\n" => " ", "\"" => "'")
                    if occursin(" must hold. Got ", message)
                        local violated, reason = split(message, " must hold. Got ")
                        @error "Template validation error" component = cname violated reason
                    else
                        @error "Template validation error" component = cname message =
                            replace(e.msg, "\n" => "; ", "\"" => "'")
                    end

                    $(:__valid__) = false
                else
                    local cname = $(:__component__)
                    rethrow(ErrorException("""Got unexpected error while validating the template.
                    ------------
                    > COMPONENT: $cname
                    ------------
                    > ERROR: $e
                    ------------
                    """))
                end
            end
        end,
    )
end

function _build_template_function_validate(template::CoreTemplate)
    if !haskey(template.yaml, "functions") || !haskey(template.yaml["functions"], "validate")
        template.functions[:validate] = (::Dict{String, Any}, ::String) -> true
        return nothing
    end

    # Get code from "validate" and remove trailing newline.
    code = chomp(template.yaml["functions"]["validate"])

    # Parse the code into an expression.
    code_ex = Meta.parse("""begin\n$(code)\nend"""; filename="$(template.name).iesopt.template.yaml")

    # Convert into a proper function.
    template.functions[:validate] = @RuntimeGeneratedFunction(
        :(function (__parameters__::Dict{String, Any}, __component__::String)
            __MODEL__ = Utilities.ModelWrapper($(template).model)
            __template_name__ = $(template).name

            this = (
                get = (s, args...) -> _get_parameter_safe(s, __parameters__, args...),
                get_ts = (s::String) -> _get_timeseries_safe(s, __parameters__, __MODEL__.iesopt_model),
                self = _get_parameter_safe("self", "__parameters__"),
                model = __MODEL__,
            )

            __valid__ = true
            try
                $code_ex
            catch e
                template = __template_name__
                component = __component__
                @error "Error while validating component" error = string(e) template component
                rethrow(e)
            end
            return __valid__
        end)
    )

    return nothing
end
