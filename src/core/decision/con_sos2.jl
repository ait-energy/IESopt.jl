@doc raw"""
    _decision_con_sos2!(decision::Decision)

to be added
"""
function _decision_con_sos2!(decision::Decision)
    if decision.mode != :sos2
        return nothing
    end

    model = decision.model

    decision.con.sos_set = @constraint(
        model,
        decision.var.sos in JuMP.SOS2(),      # todo: calculate proper weights for induced order
        base_name = _base_name(decision, "sos_set")
    )

    decision.con.sos2 =
        @constraint(model, sum(v for v in decision.var.sos) == 1.0, base_name = _base_name(decision, "sos2"))   # todo: modify this based on fixed

    return nothing
end
