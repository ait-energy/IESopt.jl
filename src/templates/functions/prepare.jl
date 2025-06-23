function _build_template_function_prepare(template::CoreTemplate)
    if !haskey(template.yaml, "functions") || !haskey(template.yaml["functions"], "prepare")
        template.functions[:prepare] = (::Virtual) -> nothing
        return nothing
    end

    # Get code from "prepare" and remove trailing newline.
    code = chomp(template.yaml["functions"]["prepare"])

    rgf_id = Tuple(reinterpret(UInt32, SHA.sha1(chomp(code))))

    # Parse the code into an expression.
    code_ex = Meta.parse("""begin\n$(code)\nend"""; filename="$(template.name).iesopt.template.yaml")

    # Convert into a proper function.
    template.functions[:prepare] = _compile_rgf(
        :(function (__virtual__::Virtual)
            __template_name__ = $(template).name
            __parameters__ = __virtual__._parameters
            __model__ = __virtual__.model
            this = __virtual__

            try
                $code_ex
            catch e
                template = __template_name__
                component = __virtual__.name
                @error "Error while preparing component" error = string(e) template component
                rethrow(e)
            end
            return nothing
        end);
        id=rgf_id,
    )

    return nothing
end
