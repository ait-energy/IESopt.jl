@doc raw"""
    _unit_obj_startup_cost!(model::JuMP.Model, unit::Unit)

Add the (potential) cost of this `unit`'s startup behaviour (configured by `unit.startup_cost` if
`unit.unit_commitment != :off`).

```math
\sum_{t \in T} \text{startup}_t \cdot \text{startupcost}
```
"""
function _unit_obj_startup_cost!(unit::Unit)
    if isnothing(unit.startup_cost) || (unit.unit_commitment === :off)
        return nothing
    end

    model = unit.model

    unit.obj.startup_cost = JuMP.AffExpr(0.0)
    for t in get_T(model)
        JuMP.add_to_expression!(unit.obj.startup_cost, unit.var.startup[t], unit.startup_cost)
    end

    push!(_iesopt(model).model.objectives["total_cost"].terms, unit.obj.startup_cost)

    return nothing
end
