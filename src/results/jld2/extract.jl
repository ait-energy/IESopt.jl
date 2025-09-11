function _convert_to_result(@nospecialize(component::_CoreComponent))
    ret = _CoreComponentResult(
        Dict{Symbol, Any}(f => getfield(component, f) for f in _result_fields(component)),
        _CoreComponentOptResultContainer(),
    )

    for field in [:exp, :var, :obj]
        for (k, v) in getfield(getproperty(component, field), :dict)
            setproperty!(getproperty(ret, field), k, JuMP.value.(v))
        end
    end

    if JuMP.has_duals(component.model)
        # Reduced costs for variables.
        if @config(component.model, results.enabled) == :all
            prop_ret_var = getproperty(ret, :var)
            for (k, v) in getfield(getproperty(component, :var), :dict)
                any(x -> isa.(x, JuMP.VariableRef), v) || continue # skip if not a variable (pf_theta can be Float64)
                setproperty!(prop_ret_var, Symbol("$(k)__dual"), JuMP.reduced_cost.(v))
            end
        elseif @config(component.model, results.enabled) == :reduced
            @debug "[optimize > results > JLD2] Skip extracting reduced costs for variables"
        end

        # Shadow prices for constraints.
        prop_ret_con = getproperty(ret, :con)
        for (k, v) in getfield(getproperty(component, :con), :dict)
            if @config(component.model, results.enabled) == :reduced
                # Only extract duals for stateless nodes, since those correspond to "energy prices".
                isa(component, Node) || continue
                component.has_state && continue
            end
            setproperty!(prop_ret_con, Symbol("$(k)__dual"), JuMP.shadow_price.(v))
        end
    end

    # Manually add the type and extracted fields for better access when loading results.
    getfield(ret, :_info)[:__type] = string(_component_type(component))
    getfield(ret, :_info)[:__fields] = _result_fields(component)

    return ret
end

function _extract_results(model::JuMP.Model)
    @info "[optimize > results > JLD2] Begin extracting results"
    # TODO: support multiple results (from MOA)

    result_components = internal(model).results.components
    result_objectives = internal(model).results.objectives
    result_customs = internal(model).results.customs
    components = internal(model).model.components

    model_has_duals = JuMP.has_duals(model)

    _safe_get(jump_data::Any) = hasproperty(jump_data, :data) ? jump_data.data : jump_data

    # Prepare any custom objects (added to the JuMP model manually; must be named ones).
    for (n, v) in JuMP.object_dictionary(model)
        if any(x -> isa.(x, JuMP.VariableRef), v)
            result_customs[n] = JuMP.value.(_safe_get(v))
            if model_has_duals
                result_customs[Symbol("$(n)__dual")] = JuMP.reduced_cost.(_safe_get(v))
            end
        elseif model_has_duals && any(x -> isa.(x, JuMP.ConstraintRef), v)
            result_customs[Symbol("$(n)__dual")] = JuMP.shadow_price.(_safe_get(v))
        elseif any(x -> isa.(x, JuMP.AffExpr), v)
            result_customs[n] = JuMP.value.(_safe_get(v))
        end
    end

    merge!(result_components, Dict(k => _convert_to_result(v) for (k, v) in components))
    merge!(result_objectives, Dict(k => JuMP.value(v.expr) for (k, v) in internal(model).model.objectives))

    # Add results that were defined by Core Templates.
    for (component_name, entry) in internal(model).results._templates
        symbolized_parameters = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in entry.virtual._parameters)
        # TODO: extract user defined results (properly)
        # for item in entry.items
        #     _result = _CoreComponentResult(symbolized_parameters, _CoreComponentOptResultContainer())
        #     setproperty!(getproperty(_result, :res), Symbol(item.name), JuMP.value.(item.expr))
        #     result_components[component_name] = _result
        # end
    end

    return nothing
end
