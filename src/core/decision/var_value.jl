@doc raw"""
    _decision_var_value!(decision::Decision)

Add the variable describing the `value` of this `decision` to the `model`. If lower and upper
bounds (`decision.lb` and `decision.ub`) are the same, the variable will immediately be fixed to that
value. This can be accessed via `decision.var.value`.
"""
function _decision_var_value!(decision::Decision)
    model = decision.model

    decision.var.value = @variable(
        model,
        binary = (decision.mode === :binary),
        integer = (decision.mode === :integer),
        base_name = _base_name(decision, "value")
    )

    if decision.mode === :fixed
        JuMP.fix(decision.var.value, decision.fixed_value)
    else
        if !isnothing(decision.ub) && (decision.lb == decision.ub)
            JuMP.fix(decision.var.value, decision.lb)
        else
            if !isnothing(decision.lb)
                JuMP.set_lower_bound(decision.var.value, decision.lb)
            end
            if !isnothing(decision.ub)
                JuMP.set_upper_bound(decision.var.value, decision.ub)
            end
        end
    end

    return nothing
end
