@doc raw"""
    _connection_con_flow_bounds!(model::JuMP.Model, connection::Connection)

Add the constraint defining the bounds of the flow (related to `connection`) to the `model`.

Specifying `capacity` will lead to symmetric bounds (``\text{lb} := -capacity`` and ``\text{ub} := capacity``), while
asymmetric bounds can be set by explicitly specifying `lb` and `ub`.

!!! note
    Usage of `etdf` is currently not fully tested, and not documented.

Upper and lower bounds can be "infinite" (by not setting them) resulting in the respective constraints not being added,
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
    components = internal(model).model.components

    # todo: rework only getting/checking lb/ub once
    if !_isempty(connection.capacity) || !_isempty(connection.lb)
        ccflb = connection.con.flow_lb = Vector{JuMP.ConstraintRef}(undef, get_T(model)[end])
    end
    if !_isempty(connection.capacity) || !_isempty(connection.ub)
        ccfub = connection.con.flow_ub = Vector{JuMP.ConstraintRef}(undef, get_T(model)[end])
    end

    if !isnothing(connection.etdf)
        etdf_flow = sum(components[id].exp.injection .* connection.etdf[id] for id in keys(connection.etdf))
    end

    cvf = connection.var.flow::Vector{JuMP.VariableRef}
    for t in get_T(model)
        # If a Snapshot is representative, it's either representative or there are no activated representative Snapshots.
        !internal(model).model.snapshots[t].is_representative && continue

        # NOTE: See below for a rough outline how the naive constraints were being constructed.
        if _isempty(connection.capacity)
            v = cvf[t]::JuMP.VariableRef

            if !_isempty(connection.lb)
                b = access(connection.lb, t, NonEmptyScalarExpressionValue)::NonEmptyScalarExpressionValue
                ccflb[t] = @constraint(
                    model::JuMP.Model,
                    v >= b,
                    base_name = make_base_name(connection, "flow_lb", t)
                )::JuMP.ConstraintRef
            end

            if !_isempty(connection.ub)
                b = access(connection.ub, t, NonEmptyScalarExpressionValue)::NonEmptyScalarExpressionValue
                ccfub[t] = @constraint(
                    model::JuMP.Model,
                    v <= b,
                    base_name = make_base_name(connection, "flow_ub", t)
                )::JuMP.ConstraintRef
            end
        else
            c = access(connection.capacity, t, NonEmptyScalarExpressionValue)::NonEmptyScalarExpressionValue
            v = cvf[t]::JuMP.VariableRef

            e = JuMP.@expression(model::JuMP.Model, c + v)
            ccflb[t] = @constraint(
                model::JuMP.Model,
                e::JuMP.AffExpr >= 0.0,
                base_name = make_base_name(connection, "flow_lb", t)
            )::JuMP.ConstraintRef

            JuMP.add_to_expression!(e, v, -2.0)
            ccfub[t] = @constraint(
                model::JuMP.Model,
                e::JuMP.AffExpr >= 0.0,
                base_name = make_base_name(connection, "flow_ub", t)
            )::JuMP.ConstraintRef
        end

        # # Calculate proper lower and upper bounds of the flow.
        # lb = _isempty(connection.capacity) ? access(connection.lb, t, NonEmptyScalarExpressionValue) : -access(connection.capacity, t, NonEmptyScalarExpressionValue)
        # ub = _isempty(connection.capacity) ? access(connection.ub, t, NonEmptyScalarExpressionValue) : access(connection.capacity, t, NonEmptyScalarExpressionValue)

        # constrained_flow = if !isnothing(connection.etdf)
        #     etdf_flow
        # elseif _hasexp(connection, :pf_flow)
        #     connection.exp.pf_flow
        # else
        #     connection.var.flow
        # end

        # if !isnothing(lb)
        #     connection.con.flow_lb[t] =
        #         @constraint(model, constrained_flow[t] >= lb, base_name = make_base_name(connection, "flow_lb", t))
        # end
        # if !isnothing(ub)
        #     connection.con.flow_ub[t] =
        #         @constraint(model, constrained_flow[t] <= ub, base_name = make_base_name(connection, "flow_ub", t))
        # end
    end

    if _has_representative_snapshots(model)
        # Use the constructed representatives.
        for t in get_T(model)
            internal(model).model.snapshots[t].is_representative && continue

            if !_isempty(connection.capacity) || !_isempty(connection.lb)
                connection.con.flow_lb[t] = connection.con.flow_lb[internal(model).model.snapshots[t].representative]
            end
            if !_isempty(connection.capacity) || !_isempty(connection.ub)
                connection.con.flow_ub[t] = connection.con.flow_ub[internal(model).model.snapshots[t].representative]
            end
        end
    end

    # Handle constraint safety (if enabled).
    if connection.soft_constraints
        _for_lb = !_isempty(connection.capacity) || !_isempty(connection.lb)
        _for_ub = !_isempty(connection.capacity) || !_isempty(connection.ub)

        for t in get_T(model)
            # Skip constraint safety for non-representative Snapshots.
            !internal(model).model.snapshots[t].is_representative && continue

            if _for_lb
                internal(model).aux.soft_constraints_penalties[connection.con.flow_lb[t]] = (
                    component_name=connection.name,
                    t=t,
                    description="flow_lb",
                    penalty=connection.soft_constraints_penalty,
                )
            end
            if _for_ub
                internal(model).aux.soft_constraints_penalties[connection.con.flow_ub[t]] = (
                    component_name=connection.name,
                    t=t,
                    description="flow_ub",
                    penalty=connection.soft_constraints_penalty,
                )
            end
        end
    end
end
