@doc raw"""
    _unit_con_conversion_bounds!(model::JuMP.Model, unit::Unit)

Add the constraint defining the `unit`'s conversion bounds to the `model`.

This makes use of the current `min_capacity` (describing the lower limit of conversion; either 0 if no minimum load
applies or the respective value of the minimum load) as well as the `online_capacity` (that can either be the full
capacity if unit commitment is disabled, or the amount that is currently active).

Depending on how the "availability" of this `unit` is handled it constructs the following constraints:

> `if !isnothing(unit.availability)`
> ```math
> \begin{aligned}
>     & \text{conversion}_t \geq \text{capacity}_{\text{min}, t}, \qquad \forall t \in T \\
>     & \text{conversion}_t \leq \text{capacity}_{\text{online}, t}, \qquad \forall t \in T \\
>     & \text{conversion}_t \leq \text{availability}_t, \qquad \forall t \in T
> \end{aligned}
> ```

This effectively results in
``\text{conversion}_t \leq \min(\text{capacity}_{\text{online}, t}, \text{availability}_t)``.

> `if !isnothing(unit.availability_factor)`
> ```math
> \begin{aligned}
>     & \text{conversion}_t \geq \text{capacity}_{\text{min}, t}, \qquad \forall t \in T \\
>     & \text{conversion}_t \leq \text{capacity}_{\text{online}, t} \cdot \text{availability}_{\text{factor}, t}, \qquad \forall t \in T
> \end{aligned}
> ```

!!! info
    If one is able to choose between using `availability` or `availability_factor` (e.g. for restricting available
    capacity during a planned revision to half the units capacity), enabling `availability_factor` (in this example 0.5)
    will result in a faster model (build and probably solve) since it makes use of one less constraint.

If no kind of availability limiting takes place, the following bounds are enforced:

> ```math
> \begin{aligned}
>     & \text{conversion}_t \geq \text{capacity}_{\text{min}, t}, \qquad \forall t \in T \\
>     & \text{conversion}_t \leq \text{capacity}_{\text{online}, t}, \qquad \forall t \in T
> \end{aligned}
> ```
"""
function _unit_con_conversion_bounds!(unit::Unit)
    model = unit.model

    limits = _unit_capacity_limits(unit)

    # Construct the lower bound.
    #   `var_conversion[t] >= 0`
    # which is already covered in the construction of the variable.

    if isnothing(limits[:online])
        return nothing
    end

    uvc = unit.var.conversion::Vector{JuMP.VariableRef}
    uc = unit.capacity::Expression

    if !_has_representative_snapshots(model)
        # Construct the upper bound.
        unit.con.conversion_ub = @constraint(
            model,
            [t = get_T(model)],
            # NOTE: this is `min[t] * capacity[t] + conversion[t] <= online[t] * capacity[t]`
            # equal to: conversion[t] <= capacity[t] * (online[t] - min[t])
            uvc[t] <= access(uc, t, NonEmptyScalarExpressionValue) * (_get(limits[:online], t) - _get(limits[:min], t)),
            base_name = make_base_name(unit, "conversion_ub"),
            container = Array
        )
    else
        # TODO: reformulate as above to cache access
        # Create all representatives.
        _repr = Dict(
            t => @constraint(
                model,
                _get(limits[:min], t) * access(uc, t, NonEmptyScalarExpressionValue) + uvc[t] <=
                _get(limits[:online], t) * access(uc, t, NonEmptyScalarExpressionValue),
                base_name = make_base_name(unit, "conversion_ub[t]")
            ) for t in get_T(model) if internal(model).model.snapshots[t].is_representative
        )

        # Create all constraints, either as themselves or their representative.
        unit.con.conversion_ub = collect(
            internal(model).model.snapshots[t].is_representative ? _repr[t] :
            _repr[internal(model).model.snapshots[t].representative] for t in get_T(model)
        )
    end

    return nothing
end
