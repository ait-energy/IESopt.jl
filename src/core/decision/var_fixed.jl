@doc raw"""
    _decision_var_fixed!(decision::Decision)

to be added
"""
function _decision_var_fixed!(decision::Decision)
    if isnothing(decision.fixed_cost) || (decision.mode === :sos1)
        return
    end

    model = decision.model
    decision.var.fixed = @variable(model, binary = true, base_name = make_base_name(decision, "fixed"))

    return nothing
end
