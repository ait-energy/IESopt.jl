@doc raw"""
    _connection_obj_cost!(model::JuMP.Model, connection::Connection)

Add the (potential) cost of this `connection` to the global objective function.

The `connection.cost` setting introduces a fixed cost of "transportation" to the flow of this `Connection`. It is based
on the directed flow. This means that flows in the "opposite" direction will lead to negative costs:

```math
\sum_{t \in T} \text{flow}_t \cdot \text{cost}_t \cdot \omega_t
```

Here $\omega_t$ is the weight of `Snapshot` `t`.

!!! note "Costs for flows in both directions"
    If you need to apply a cost term to the absolute value of the flow, consider splitting the `Connection` into two
    different ones, in opposing directions, and including `lb = 0`.
"""
function _connection_obj_cost!(connection::Connection)
    if _isempty(connection.cost)
        return nothing
    end

    model = connection.model

    connection.obj.cost = _isparametric(profile.cost) ? zero(JuMP.QuadExpr) : zero(JuMP.AffExpr)
    for t in get_T(connection.model)
        JuMP.add_to_expression!(
            connection.obj.cost,
            connection.var.flow[t],
            _weight(model, t) * access(connection.cost, t),
        )
    end

    push!(internal(model).model.objectives["total_cost"].terms, connection.obj.cost)

    return nothing
end
