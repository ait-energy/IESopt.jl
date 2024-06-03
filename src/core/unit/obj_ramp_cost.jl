@doc raw"""
    _unit_obj_ramp_cost!(model::JuMP.Model, unit::Unit)

Add the (potential) cost of this `unit`'s ramping to the global objective function.

To allow for finer control, costs of up- and downwards ramping can be specified separately (using `unit.ramp_up_cost`
and `unit.ramp_down_cost`):

```math
\sum_{t \in T} \text{ramp}_{\text{up}, t} \cdot \text{rampcost}_{\text{up}} + \text{ramp}_{\text{down}, t} \cdot \text{rampcost}_{\text{down}}
```
"""
function _unit_obj_ramp_cost!(unit::Unit)
    unit.enable_ramp_up || unit.enable_ramp_down || return nothing

    model = unit.model

    unit.obj.ramp_cost = JuMP.AffExpr(0.0)
    if unit.enable_ramp_up && !isnothing(unit.ramp_up_cost)
        JuMP.add_to_expression!(
            unit.obj.ramp_cost,
            _affine_expression(unit.var.ramp_up[t] * unit.ramp_up_cost for t in _iesopt(model).model.T),
        )
    end
    if unit.enable_ramp_down && !isnothing(unit.ramp_down_cost)
        JuMP.add_to_expression!(
            unit.obj.ramp_cost,
            _affine_expression(unit.var.ramp_down[t] * unit.ramp_down_cost for t in _iesopt(model).model.T),
        )
    end

    push!(_iesopt(model).model.objectives["total_cost"].terms, unit.obj.ramp_cost)
    return nothing
end
