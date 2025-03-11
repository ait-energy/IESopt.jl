@doc raw"""
    _decision_obj_value!(decision::Decision)

Add the cost defined by the value of this `Decision` to the `model`:

```math
\text{value} \cdot \text{cost}
```
"""
function _decision_obj_value!(decision::Decision)
    if isnothing(decision.cost) || (decision.mode === :sos1 || decision.mode === :sos2)
        return nothing
    end

    model = decision.model
    decision.obj.value = decision.var.value * access(decision.cost)
    push!(internal(model).model.objectives["total_cost"].terms, decision.obj.value)

    return nothing
end
