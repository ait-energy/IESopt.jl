# Note: This uses `_unit_capacity_limits` from `constr_conversion_ub.jl`.

@doc raw"""
    _unit_con_ramp_limit!(model::JuMP.Model, unit::Unit)

Add the constraint describing the ramping limits of this `unit` to the `model`.

This makes use of the maximum capacity of the `unit`, which is just the total installed capacity. Both, up- and
downwards ramps can be enabled separately (via `unit.ramp_up_limit` and `unit.ramp_down_limit`), resulting in either or
both of:

```math
\begin{aligned}
    & \text{ramp}_{\text{up}, t} \leq \text{ramplimit}_\text{up} \cdot \text{capacity}_\text{max} \cdot \omega_t, \qquad \forall t \in T \\
    & \text{ramp}_{\text{down}, t} \leq \text{ramplimit}_\text{down} \cdot \text{capacity}_\text{max} \cdot \omega_t, \qquad \forall t \in T
\end{aligned}
```

This does **not** make use of the ramping variable (that is only used for costs - if there are costs).

This calculates the ramping that happens from the PREVIOUS snapshot to this one. That means that if:
- `out[5] = 100` and `out[4] = 50`, then `ramp_up[5] = 50` and `ramp_down[5] = 0`
- `ramp_up[1] = ramp_down[1] = 0`
"""
function _unit_con_ramp_limit!(unit::Unit)
    model = unit.model

    # Extract the unique capacity carrier, which ramps are based on.
    out = _total(unit, unit.capacity_carrier.inout, unit.capacity_carrier.carrier.name)

    if unit.enable_ramp_up && !isnothing(unit.ramp_up_limit)
        unit.con.ramp_up_limit = @constraint(
            model,
            [t = get_T(model)],
            out[t] - ((t == 1) ? out[t] : out[t - 1]) <=
            unit.ramp_up_limit *
            _weight(model, t) *
            access(unit.unit_count, Float64) *
            access(unit.capacity, t, NonEmptyScalarExpressionValue),
            base_name = make_base_name(unit, "ramp_up_limit"),
            container = Array
        )
    end
    if unit.enable_ramp_down && !isnothing(unit.ramp_down_limit)
        unit.con.ramp_down_limit = @constraint(
            model,
            [t = get_T(model)],
            ((t == 1) ? out[t] : out[t - 1]) - out[t] <=
            unit.ramp_down_limit *
            _weight(model, t) *
            access(unit.unit_count, Float64) *
            access(unit.capacity, t, NonEmptyScalarExpressionValue),
            base_name = make_base_name(unit, "ramp_down_limit"),
            container = Array
        )
    end
end
