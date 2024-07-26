function _parse_field_docstring(docstring::String)
    # Split docstring into "spec" fields and "description".
    rm = match(r"```(\{.*?\})```((?s).*)", docstring)
    isnothing(rm) && return ret_error
    length(rm.captures) == 2 || return ret_error
    str_specs, str_descr = string.(rm.captures)

    # Parse specs as JSON, load description as string.
    specs = JSON.parse(str_specs)
    descr = replace(strip(str_descr), "\n" => " ")

    # Return specs (in correct order) and description.
    return ([specs[s] for s in ["mandatory", "values", "unit", "default"]]..., descr)
end

function _docs_struct_to_table(datatype::Type)
    # Start table with proper header.
    table_rows = [
        "| Name | Mandatory | Values | Unit | Default | Description |",
        "|:-----|:----------|:-------|:-----|:--------|:------------|",
    ]

    # Get proper binding from module, error if structure is unexpected.
    binding = Base.Docs.aliasof(datatype, typeof(datatype))
    dict = Base.Docs.meta(binding.mod; autoinit=false)
    isnothing(dict) && @critical "Doc error occured" datatype
    haskey(dict, binding) || @critical "Doc error occured" datatype dict binding
    multidoc = dict[binding]
    haskey(multidoc.docs, Union{}) || @critical "Doc error occured" datatype multidoc.docs

    # Get all fields that have a docstring.
    all_doc_fields = multidoc.docs[Union{}].data[:fields]

    # Get all fields in the order they are defined (`all_doc_fields` is an unordered dictionary).
    all_fields = fieldnames(datatype)

    # Create a row for each field, properly splitting the docstring.
    for field in all_fields
        haskey(all_doc_fields, field) || continue
        field_attrs = join(_parse_field_docstring(all_doc_fields[field]), " | ")
        push!(table_rows, "| `$(field)` | $(field_attrs) |")
    end

    # Join all rows to the string representation of the table and parse it to Markdown.
    return Markdown.parse(join(table_rows, "\n"))
end

function _docs_docstr_to_admonition(f::Function)
    f_name = string(f)
    obj_cc, obj_type, obj_name = string.(match(r"_([^_]+)_([^_]+)_(.*)!", f_name).captures)
    obj_longtype =
        Dict("var" => "variable", "exp" => "expression", "con" => "constraint", "obj" => "objective")[obj_type]
    f_path = "ait-energy/IESopt.jl/tree/main/src/core/$(obj_cc)/$(obj_type)_$(obj_name).jl"

    header = """
    !!! tip "How to?"
        Access this $(obj_longtype) by using:
        ```julia
        # Julia
        component(model, "your_$(obj_cc)").$(obj_type).$(obj_name)
        ```
        ```python
        # Python
        model.get_component("your_$(obj_cc)").$(obj_type).$(obj_name)
        ```

        You can find the full implementation and all details here: [`IESopt.jl`](https://github.com/$(f_path)).
    """

    docstr = string(Base.Docs.doc(f))
    docstr = replace(docstr, r"```(?s).*```" => header)
    docstr = replace(docstr, "\n" => "\n    ", "\$\$" => "```math")      # TODO

    return """
    !!! details "$obj_name"
        $(docstr)
    """
end

function _docs_make_parameters(datatype::Type)
    return """
    # Parameters

    $(_docs_struct_to_table(datatype))
    """
end

function _docs_make_model_reference(datatype::Type)
    lc_type = lowercase(string(nameof(datatype)))
    registered_names = string.(names(@__MODULE__; all=true, imported=false))
    valid_names = filter(n -> startswith(n, "_$(lc_type)_"), registered_names)

    var_names = filter(n -> startswith(n, "_$(lc_type)_var_"), valid_names)
    exp_names = filter(n -> startswith(n, "_$(lc_type)_exp_"), valid_names)
    con_names = filter(n -> startswith(n, "_$(lc_type)_con_"), valid_names)
    obj_names = filter(n -> startswith(n, "_$(lc_type)_obj_"), valid_names)

    return """
    # Detailed Model Reference

    ## Variables

    $(join([_docs_docstr_to_admonition(getfield(@__MODULE__, Symbol(n))) for n in var_names], "\n\n"))

    ## Expressions

    $(join([_docs_docstr_to_admonition(getfield(@__MODULE__, Symbol(n))) for n in exp_names], "\n\n"))

    ## Constraints

    $(join([_docs_docstr_to_admonition(getfield(@__MODULE__, Symbol(n))) for n in con_names], "\n\n"))

    ## Objectives

    $(join([_docs_docstr_to_admonition(getfield(@__MODULE__, Symbol(n))) for n in obj_names], "\n\n"))
    """
end

function _finalize_docstring(datatype::Type)
    binding = Base.Docs.aliasof(datatype, typeof(datatype))
    multidoc = Base.Docs.meta(@__MODULE__)[binding]
    old_data = multidoc.docs[Union{}].data

    multidoc.docs[Union{}] = Base.Docs.docstr("""
    $(Base.Docs.doc(datatype))

    $(_docs_make_parameters(datatype))

    $(_docs_make_model_reference(datatype))
    """)
    multidoc.docs[Union{}].data = old_data

    return nothing
end
