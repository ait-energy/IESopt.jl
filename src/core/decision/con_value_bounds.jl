@doc raw"""
    _decision_con_value_bounds!(decision::Decision)

to be added
"""
function _decision_con_value_bounds!(decision::Decision)
    if !_isempty(decision.lb)
        decision.con.value_lb = @constraint(
            decision.model,
            decision.var.value >= access(decision.lb),
            base_name = make_base_name(decision, "value_lb")
        )
    end

    if !_isempty(decision.ub)
        decision.con.value_ub = @constraint(
            decision.model,
            decision.var.value <= access(decision.ub),
            base_name = make_base_name(decision, "value_ub")
        )
    end

    return nothing
end
