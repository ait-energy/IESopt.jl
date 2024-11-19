@doc raw"""
    _unit_con_startup!(model::JuMP.Model, unit::Unit)

Add the auxiliary constraint that enables calculation of per snapshot startup to the `model`.

Depending on whether startup handling is enabled, the following constraint is constructed:

```math
\begin{aligned}
    & \text{startup}_{\text{up}, t} \geq \text{ison}_{t} - \text{ison}_{t-1}, \qquad \forall t \in T
\end{aligned}
```

This calculates the startup that happens from the PREVIOUS snapshot to this one. That means that if:
- `ison[5] = 1` and `ison[4] = 0`, then `startup[5] = 1`
"""
function _unit_con_startup!(unit::Unit)
    if isnothing(unit.startup_cost) || (unit.unit_commitment === :off)
        return nothing
    end

    model = unit.model

    unit.con.startup_lb = @constraint(
        model,
        [t = get_T(model)],
        unit.var.startup[t] >= unit.var.ison[t] - ((t == 1) ? unit.is_on_before : unit.var.ison[t - 1]),
        base_name = make_base_name(unit, "startup_lb"),
        container = Array
    )

    return nothing

    # The following constraint is currently not active, since it should never be necessary (= model will never startup
    # more units than are available).
    # unit.constr_startup_ub = @constraint(
    #     model, [t=get_T(model)],
    #     unit.var.startup[t] <= _get(unit.unit_count),
    #     base_name = make_base_name(model, "unit_startup_ub", (n=unit.name, t=_snapshot(model, t).name))
    # )
end
