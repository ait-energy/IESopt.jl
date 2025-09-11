@doc raw"""
    _decision_obj_fixed!(decision::Decision)

to be added
```
"""
function _decision_obj_fixed!(decision::Decision)
    if _isempty(decision.fixed_cost) && decision.mode != :sos1
        return
    end

    model = decision.model

    decision.obj.fixed = JuMP.AffExpr(0.0)
    if decision.mode === :sos1
        for i in eachindex(decision.sos)
            if haskey(decision.sos[i], "fixed_cost")
                if !_isempty(decision.fixed_cost)
                    @warn "Decision is overwriting global fixed_cost based on SOS1 local" decision = decision.name maxlog =
                        1
                end

                JuMP.add_to_expression!(decision.obj.fixed, decision.var.sos[i], decision.sos[i]["fixed_cost"])
            elseif !_isempty(decision.fixed_cost)
                JuMP.add_to_expression!(decision.obj.fixed, decision.var.sos[i], access(decision.fixed_cost))
            end
        end
    else
        JuMP.add_to_expression!(decision.obj.fixed, decision.var.fixed, access(decision.fixed_cost))
    end

    push!(internal(model).model.objectives["total_cost"].terms, decision.obj.fixed)

    return nothing
end
