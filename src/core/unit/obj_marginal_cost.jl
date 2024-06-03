@doc raw"""
    _unit_obj_marginal_cost!(model::JuMP.Model, unit::Unit)

Add the (potential) cost of this `unit`'s conversion (`unit.marginal_cost`) to the global objective function.

```math
\sum_{t \in T} \text{conversion}_t \cdot \text{marginalcost}_t \cdot \omega_t
```
"""
function _unit_obj_marginal_cost!(unit::Unit)
    if isnothing(unit.marginal_cost)
        return nothing
    end

    model = unit.model
    total_mc::Vector{JuMP.AffExpr} =
        _total(unit, unit.marginal_cost_carrier.inout, unit.marginal_cost_carrier.carrier.name)

    unit.obj.marginal_cost = JuMP.AffExpr(0.0)
    for t in _iesopt(model).model.T
        JuMP.add_to_expression!(
            unit.obj.marginal_cost,
            total_mc[_iesopt(model).model.snapshots[t].representative],
            _weight(model, t) * _get(unit.marginal_cost, t),
        )
    end

    push!(_iesopt(model).model.objectives["total_cost"].terms, unit.obj.marginal_cost)

    return nothing
end
