@doc raw"""
    _decision_obj_fixed!(decision::Decision)

to be added
```
"""
function _decision_obj_fixed!(decision::Decision)
    _isempty(decision.fixed_cost) && return nothing

    model = decision.model

    decision.obj.fixed = JuMP.AffExpr(0.0)
    JuMP.add_to_expression!(decision.obj.fixed, decision.var.fixed, access(decision.fixed_cost))

    push!(internal(model).model.objectives["total_cost"].terms, decision.obj.fixed)

    return nothing
end
