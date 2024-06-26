"""
    @add_result

Add a custom result to the current model.

# Example

```yaml
functions:
  finalize: |
    @add_result "setpoint" (
        access("discharge").exp.out_electricity -
        access("charge").exp.in_electricity
    )
```

See ["Template Finalization"](@ref manual_templates_finalization) in the documentation for more information.

!!! warning "Usage outside of Core Template finalization"
    This requires `__component__`, and `MODEL` to be set outside of calling the macro.
"""
macro add_result(result_name, result_expr, args...)
    if !isempty(args)
        return esc(quote
            @critical "`@add_result` got more than two arguments" component = __component__
        end)
    end

    return esc(quote
        try
            local templates = _iesopt(MODEL.model).results._templates
            push!(templates[__component__].items, (name=$result_name, expr=$result_expr))
        catch e
            local cname = $(:__component__)
            rethrow(ErrorException("""Got unexpected error while finalizing a template instance.
            ------------
            > COMPONENT: $cname
            > RESULT: $($result_name)
            ------------
            > ERROR: $e
            ------------
            """))
        end
    end)
end

function _build_template_function_finalize(template::CoreTemplate)
    if !haskey(template.yaml, "functions") || !haskey(template.yaml["functions"], "finalize")
        template.functions[:finalize] = (::JuMP.Model, ::String, ::Dict{String, Any}) -> nothing
        return nothing
    end

    # Get code from "finalize" and remove trailing newline.
    code = chomp(template.yaml["functions"]["finalize"])

    # Replace the `get` function (that would otherwise conflict with Julia's `get` function).
    code = replace(code, r"""get\("([^"]+)"\)""" => s"""_get_parameter_safe("\1", __parameters__)""")

    # Parse the code into an expression.
    code_ex = Meta.parse("""begin\n$(code)\nend"""; filename="$(template.name).iesopt.template.yaml")

    # Convert into a proper function.
    template.functions[:finalize] = @RuntimeGeneratedFunction(
        :(function (__model__::JuMP.Model, __component__::String, __parameters__::Dict{String, Any})
            MODEL = Utilities.ModelWrapper(__model__)
            __template_name__ = $(template).name

            get_ts(s::String) = _get_timeseries_safe(s, __parameters__, __model__)
            access(sub::String) = component(__model__, "$(__component__).$(sub)")

            try
                $code_ex
            catch e
                template = __template_name__
                component = __component__
                @error "Error while finalizing component" error = string(e) template component
                rethrow(e)
            end
            return nothing
        end)
    )

    return nothing
end
