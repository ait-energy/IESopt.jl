@doc raw"""
    _unit_obj_marginal_cost!(unit::Unit)

Add the (potential) cost of this `unit`'s conversion (`unit.marginal_cost`) to the global objective function.

```math
\sum_{t \in T} \text{conversion}_t \cdot \text{marginalcost}_t \cdot \omega_t
```
"""
function _unit_obj_marginal_cost!(unit::Unit)
    if _isempty(unit.marginal_cost)
        return nothing
    end

    model = unit.model
    total_mc::Vector{JuMP.AffExpr} =
        _total(unit, unit.marginal_cost_carrier.inout, unit.marginal_cost_carrier.carrier.name)

    unit.obj.marginal_cost = JuMP.AffExpr(0.0)
    for t in get_T(model)
        JuMP.add_to_expression!(
            unit.obj.marginal_cost,
            total_mc[internal(model).model.snapshots[t].representative],
            _weight(model, t) * access(unit.marginal_cost, t, Float64),
        )
    end

    push!(internal(model).model.objectives["total_cost"].terms, unit.obj.marginal_cost)

    return nothing
end
