@doc raw"""
    _decision_con_sos1!(decision::Decision)

to be added
"""
function _decision_con_sos1!(decision::Decision)
    if decision.mode != :sos1
        return nothing
    end

    model = decision.model

    decision.con.sos_set = @constraint(
        model,
        decision.var.sos in JuMP.SOS1([item["cost"] for item in decision.sos]),      # todo: considered fixed_cost here for the weight!
        base_name = _base_name(decision, "sos_set")
    )

    decision.con.sos1_lb = Vector{JuMP.ConstraintRef}()
    decision.con.sos1_ub = Vector{JuMP.ConstraintRef}()
    sizehint!(decision.con.sos1_lb, length(decision.sos) - 1)
    sizehint!(decision.con.sos1_ub, length(decision.sos) - 1)
    for i in eachindex(decision.sos)
        push!(
            decision.con.sos1_lb,
            @constraint(
                model,
                decision.sos[i]["lb"] * decision.var.sos[i] <= decision.var.sos1_value[i],
                base_name = _base_name(decision, "sos1_lb[$(i)]")
            )
        )
        push!(
            decision.con.sos1_ub,
            @constraint(
                model,
                decision.var.sos1_value[i] <= decision.sos[i]["ub"] * decision.var.sos[i],
                base_name = _base_name(decision, "sos1_ub[$(i)]")
            )
        )
    end

    return nothing
end
