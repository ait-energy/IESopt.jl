@doc raw"""
    _unit_con_ramp!(model::JuMP.Model, unit::Unit)

Add the auxiliary constraint that enables calculation of per snapshot ramping to the `model`.

Depending on whether ramps are enabled, none, one, or both of the following constraints are constructed:

```math
\begin{aligned}
    & \text{ramp}_{\text{up}, t} \geq \text{conversion}_{t} - \text{conversion}_{t-1}, \qquad \forall t \in T \\
    & \text{ramp}_{\text{down}, t} \geq \text{conversion}_{t-1} - \text{conversion}_{t}, \qquad \forall t \in T
\end{aligned}
```

This calculates the ramping that happens from the PREVIOUS snapshot to this one. That means that if:
- `out[5] = 100` and `out[4] = 50`, then `ramp_up[5] = 50` and `ramp_down[5] = 0`
- `ramp_up[1] = ramp_down[1] = 0`

!!! info
    This currently does not support pre-setting the initial states of the unit (it can be done manually but there is no
    exposed parameter), which will be implemented in the future to allow for easy / correct rolling optimization runs.
"""
function _unit_con_ramp!(unit::Unit)
    model = unit.model

    # Extract the unique capacity carrier, which ramps are based on.
    out = _total(unit, unit.capacity_carrier.inout, unit.capacity_carrier.carrier.name)

    if unit.enable_ramp_up && !isnothing(unit.ramp_up_cost)
        unit.con.ramp_up = @constraint(
            model,
            [t = get_T(model)],
            unit.var.ramp_up[t] >= out[t] - ((t == 1) ? out[t] : out[t - 1]),
            base_name = _base_name(unit, "ramp_up"),
            container = Array
        )
    end
    if unit.enable_ramp_down && !isnothing(unit.ramp_down_cost)
        unit.con.ramp_down = @constraint(
            model,
            [t = get_T(model)],
            unit.var.ramp_down[t] >= ((t == 1) ? out[t] : out[t - 1]) - out[t],
            base_name = _base_name(unit, "ramp_down"),
            container = Array
        )
    end
end
