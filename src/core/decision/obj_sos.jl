@doc raw"""
    _decision_obj_sos!(decision::Decision)

Add the cost defined by the SOS-based value of this `Decision` to the `model`.
"""
function _decision_obj_sos!(decision::Decision)
    if (decision.mode != :sos1) && (decision.mode != :sos2)
        return nothing
    end

    model = decision.model

    decision.obj.sos = JuMP.AffExpr(0.0)
    if decision.mode === :sos1
        for i in eachindex(decision.var.sos1_value)
            JuMP.add_to_expression!(decision.obj.sos, decision.var.sos1_value[i], decision.sos[i]["cost"])
        end
    elseif decision.mode === :sos2
        for i in eachindex(decision.var.sos)
            JuMP.add_to_expression!(decision.obj.sos, decision.var.sos[i], decision.sos[i]["cost"])
        end
    end

    push!(_iesopt(model).model.objectives["total_cost"].terms, decision.obj.sos)

    return nothing
end
