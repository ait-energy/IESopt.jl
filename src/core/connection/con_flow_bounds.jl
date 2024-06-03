@doc raw"""
    _connection_con_flow_bounds!(model::JuMP.Model, connection::Connection)

Add the constraint defining the bounds of the flow (related to `connection`) to the `model`.

Specifiying `capacity` will lead to symmetric bounds (``\text{lb} := -capacity`` and ``\text{ub} := capacity``), while
asymmetric bounds can be set by explicitly specifiying `lb` and `ub`.

!!! note
    Usage of `etdf` is currently not fully tested, and not documented.

Upper and lower bounds can be "infinite" (by not setting them) resulting in the repective constraints not being added,
and the flow variable therefore being (partially) unconstrained. Depending on the configuration the `flow` is calculated
differently:
- if `connection.etdf` is set, it is based on an ETDF sum flow,
- if `connection.exp.pf_flow` is available, it equals this
- else it equal `connection.var.flow`

This flow is then constrained:

> ```math
> \begin{aligned}
>     & \text{flow}_t \geq \text{lb}, \qquad \forall t \in T \\
>     & \text{flow}_t \leq \text{ub}, \qquad \forall t \in T
> \end{aligned}
> ```

!!! note "Constraint safety"
    The lower and upper bound constraint are subject to penalized slacks.
"""
function _connection_con_flow_bounds!(connection::Connection)
    model = connection.model
    components = _iesopt(model).model.components

    # todo: rework only getting/checking lb/ub once
    if !isnothing(connection.capacity) || !isnothing(_get(connection.lb, 1))
        connection.con.flow_lb = Vector{JuMP.ConstraintRef}(undef, _iesopt(model).model.T[end])
    end
    if !isnothing(connection.capacity) || !isnothing(_get(connection.ub, 1))
        connection.con.flow_ub = Vector{JuMP.ConstraintRef}(undef, _iesopt(model).model.T[end])
    end

    if !isnothing(connection.etdf)
        etdf_flow = sum(components[id].exp.injection .* connection.etdf[id] for id in keys(connection.etdf))
    end

    for t in _iesopt(model).model.T
        # If a Snapshot is representative, it's either representative or there are no activated representative Snapshots.
        !_iesopt(model).model.snapshots[t].is_representative && continue

        # Calculate proper lower and upper bounds of the flow.
        lb = isnothing(connection.capacity) ? _get(connection.lb, t) : -_get(connection.capacity, t)
        ub = isnothing(connection.capacity) ? _get(connection.ub, t) : _get(connection.capacity, t)

        constrained_flow = if !isnothing(connection.etdf)
            etdf_flow
        elseif _hasexp(connection, :pf_flow)
            connection.exp.pf_flow
        else
            connection.var.flow
        end

        if !isnothing(lb)
            connection.con.flow_lb[t] =
                @constraint(model, constrained_flow[t] >= lb, base_name = _base_name(connection, "flow_lb[$t]"))
        end
        if !isnothing(ub)
            connection.con.flow_ub[t] =
                @constraint(model, constrained_flow[t] <= ub, base_name = _base_name(connection, "flow_ub[$t]"))
        end
    end

    if _has_representative_snapshots(model)
        # Use the constructed representatives.
        for t in _iesopt(model).model.T
            _iesopt(model).model.snapshots[t].is_representative && continue

            if !isnothing(connection.capacity) || !isnothing(connection.lb)
                connection.con.flow_lb[t] = connection.con.flow_lb[_iesopt(model).model.snapshots[t].representative]
            end
            if !isnothing(connection.capacity) || !isnothing(connection.ub)
                connection.con.flow_ub[t] = connection.con.flow_ub[_iesopt(model).model.snapshots[t].representative]
            end
        end
    end

    # Handle constraint safety (if enabled).
    if connection.constraint_safety
        for t in _iesopt(model).model.T
            # Skip constraint safety for non-representative Snapshots.
            !_iesopt(model).model.snapshots[t].is_representative && continue

            if !isnothing(connection.capacity) || !isnothing(connection.lb)
                _iesopt(model).aux.constraint_safety_penalties[connection.con.flow_lb[t]] = (
                    component_name=connection.name,
                    t=t,
                    description="flow_lb",
                    penalty=connection.constraint_safety_cost,
                )
            end
            if !isnothing(connection.capacity) || !isnothing(connection.ub)
                _iesopt(model).aux.constraint_safety_penalties[connection.con.flow_ub[t]] = (
                    component_name=connection.name,
                    t=t,
                    description="flow_ub",
                    penalty=connection.constraint_safety_cost,
                )
            end
        end
    end
end
