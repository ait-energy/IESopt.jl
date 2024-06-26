@doc raw"""
    _node_con_last_state!(model::JuMP.Model, node::Node)

Add the constraint defining the bounds of the `node`'s state during the last Snapshot to the `model`, if
`node.has_state == true`.

This is necessary since it could otherwise happen, that the state following the last Snapshot
is actually not feasible (e.g. we could charge a storage by more than it's state allows for). The equations are based on
the construction of the overall state variable.

```math
\begin{aligned}
    & \text{state}_{end} \cdot \text{factor}^\omega_t + \text{injection}_{end} \cdot \omega_t \geq \text{state}_{lb} \\ 
    & \text{state}_{end} \cdot \text{factor}^\omega_t + \text{injection}_{end} \cdot \omega_t \leq \text{state}_{ub} 
\end{aligned}
```

Here ``\omega_t`` is the `weight` of `Snapshot` `t`, and ``\text{factor}`` is either `1.0` (if there are now percentage
losses configured), or `(1.0 - node.state_percentage_loss)` otherwise.

!!! note "Constraint safety"
    The lower and upper bound constraint are subject to penalized slacks.
"""
function _node_con_last_state!(node::Node)
    if !isnothing(node.etdf_group)
        return nothing
    end

    if !node.has_state
        return nothing
    end

    model = node.model

    factor = isnothing(node.state_percentage_loss) ? 1.0 : (1.0 - node.state_percentage_loss)
    t = _iesopt(model).model.T[end]

    injection_t = t
    if _has_representative_snapshots(model)
        if !_iesopt(model).model.snapshots[t].is_representative
            injection_t = _iesopt(model).model.snapshots[t].representative
        end
    end

    lb = _get(node.state_lb, t)
    ub = _get(node.state_ub, t)

    if !isnothing(node.state_final)
        if (!isnothing(lb) && (node.state_final < lb)) || (!isnothing(ub) && (node.state_final > ub))
            @warn "`state_final` is out of bounds and will be overwritten" node = node.name state_final =
                node.state_final lb ub
        end

        lb = node.state_final
        ub = node.state_final
    end

    if !isnothing(lb) && node.nodal_balance != :create
        node.con.last_state_lb = @constraint(
            model,
            lb <= node.var.state[t] * (factor^_weight(model, t)) + node.exp.injection[injection_t] * _weight(model, t),
            base_name = _base_name(node, "last_state_lb"),
            container = Array
        )
    end

    if !isnothing(ub) && node.nodal_balance != :destroy
        node.con.last_state_ub = @constraint(
            model,
            ub >= node.var.state[t] * (factor^_weight(model, t)) + node.exp.injection[injection_t] * _weight(model, t),
            base_name = _base_name(node, "last_state_ub")
        )
    end

    if node.constraint_safety
        if !isnothing(node.state_lb)
            _iesopt(model).aux.constraint_safety_penalties[node.con.last_state_lb] =
                (component_name=node.name, t=t, description="last_state_lb", penalty=node.constraint_safety_cost)
        end
        if !isnothing(node.state_ub)
            _iesopt(model).aux.constraint_safety_penalties[node.con.last_state_ub] =
                (component_name=node.name, t=t, description="last_state_ub", penalty=node.constraint_safety_cost)
        end
    end

    return nothing
end
