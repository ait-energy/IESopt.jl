@doc raw"""
    _decision_con_fixed!(decision::Decision)

to be added
"""
function _decision_con_fixed!(decision::Decision)
    if isnothing(decision.fixed_cost) || (decision.mode === :sos1)
        return
    end

    model = decision.model

    if decision.mode === :sos2
        decision.con.fixed = @constraint(
            model,
            decision.var.value <= decision.var.fixed * maximum(it["value"] for it in decision.sos),
            base_name = make_base_name(decision, "fixed")
        )
    else
        decision.con.fixed = @constraint(
            model,
            decision.var.value <= decision.var.fixed * decision.ub,
            base_name = make_base_name(decision, "fixed")
        )
    end

    return nothing
end
