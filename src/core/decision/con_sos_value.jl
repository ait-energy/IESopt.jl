@doc raw"""
    _decision_con_sos_value!(decision::Decision)

to be added
"""
function _decision_con_sos_value!(decision::Decision)
    if (decision.mode != :sos1) && (decision.mode != :sos2)
        return nothing
    end

    model = decision.model

    if decision.mode === :sos1
        decision.con.sos_value = @constraint(
            model,
            decision.var.value == sum(v for v in decision.var.sos1_value),
            base_name = make_base_name(decision, "sos_value")
        )
    elseif decision.mode === :sos2
        decision.con.sos_value = @constraint(
            model,
            decision.var.value ==
            _affine_expression(decision.var.sos[i] * decision.sos[i]["value"] for i in eachindex(decision.var.sos)),
            base_name = make_base_name(decision, "sos_value")
        )
    end

    return nothing
end
