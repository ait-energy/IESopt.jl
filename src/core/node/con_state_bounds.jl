@doc raw"""
    _node_con_state_bounds!(model::JuMP.Model, node::Node)

Add the constraint defining the bounds of the `node`'s state to the `model`, if `node.has_state == true`.

```math
\begin{aligned}
    & \text{state}_t \geq \text{state}_{lb}, \qquad \forall t \in T \\
    & \text{state}_t \leq \text{state}_{ub}, \qquad \forall t \in T
\end{aligned}
```

!!! note "Constraint safety"
    The lower and upper bound constraint are subject to penalized slacks.
"""
function _node_con_state_bounds!(node::Node)
    if !node.has_state
        return nothing
    end

    model = node.model

    if !isnothing(node.state_lb)
        node.con.state_lb = @constraint(
            model,
            [t = _iesopt(model).model.T],
            node.var.state[t] >= _get(node.state_lb, t),
            base_name = _base_name(node, "state_lb"),
            container = Array
        )
    end
    if !isnothing(node.state_ub)
        node.con.state_ub = @constraint(
            model,
            [t = _iesopt(model).model.T],
            node.var.state[t] <= _get(node.state_ub, t),
            base_name = _base_name(node, "state_ub"),
            container = Array
        )
    end

    # Handle constraint safety (if enabled).
    if node.constraint_safety
        if !isnothing(node.state_lb)
            @simd for t in _iesopt(model).model.T
                _iesopt(model).aux.constraint_safety_penalties[node.con.state_lb[t]] =
                    (component_name=node.name, t=t, description="state_lb", penalty=node.constraint_safety_cost)
            end
        end
        if !isnothing(node.state_ub)
            @simd for t in _iesopt(model).model.T
                _iesopt(model).aux.constraint_safety_penalties[node.con.state_ub[t]] =
                    (component_name=node.name, t=t, description="state_ub", penalty=node.constraint_safety_cost)
            end
        end
    end
end
