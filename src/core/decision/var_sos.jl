@doc raw"""
    _decision_var_sos!(decision::Decision)

to be added
"""
function _decision_var_sos!(decision::Decision)
    if (decision.mode != :sos1) && (decision.mode != :sos2)
        return nothing
    end

    model = decision.model

    decision.var.sos = @variable(
        model,
        [1:length(decision.sos)],
        binary = (decision.mode === :sos1),
        lower_bound = 0,
        base_name = make_base_name(decision, String(decision.mode)),
        container = Array
    )

    if decision.mode === :sos1
        decision.var.sos1_value = @variable(
            model,
            [1:length(decision.sos)],
            base_name = make_base_name(decision, "sos1_value"),
            container = Array
        )
    end

    return nothing
end
