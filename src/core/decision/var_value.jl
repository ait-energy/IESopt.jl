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
        base_name = make_base_name(decision, "value")
    )

    if decision.mode === :fixed
        JuMP.fix(decision.var.value, decision.fixed_value)
    end

    return nothing
end
