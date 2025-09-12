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
        JuMP.fix(decision.var.value, access(decision.fixed_value)::Float64)
    else
        if !_isempty(decision.ub) && (access(decision.lb) === access(decision.ub))
            JuMP.fix(decision.var.value, access(decision.lb))
        else
            if !_isempty(decision.lb)
                # TODO: `lb` could be something else than a scalar, which would require doing a constraint here
                JuMP.set_lower_bound(decision.var.value, access(decision.lb)::Float64)
            end
            if !_isempty(decision.ub)
                # TODO: `ub` could be something else than a scalar, which would require doing a constraint here
                JuMP.set_upper_bound(decision.var.value, access(decision.ub)::Float64)
            end
        end
    end

    return nothing
end
