@doc raw"""
    _connection_var_flow!(connection::Connection)

Add the variable representing the flow of this `connection` to the `model`. This can be accessed via
`connection.var.flow[t]`.

Additionally, the flow gets "injected" at the `Node`s that the `connection` is connecting, resulting in
```math
\begin{aligned}
   & \text{connection.node}_{from}\text{.injection}_t = \text{connection.node}_{from}\text{.injection}_t - \text{flow}_t, \qquad \forall t \in T \\
   & \text{connection.node}_{to}\text{.injection}_t = \text{connection.node}_{to}\text{.injection}_t + \text{flow}_t, \qquad \forall t \in T
\end{aligned}
```

> For "PF controlled" `Connection`s (ones that define the necessary power flow parameters), the flow variable may not be
> constructed (depending on specific power flow being used). The automatic result extraction will detect this and return
> the correct values either way. Accessing it manually can be done using `connection.exp.pf_flow[t]`.
"""
function _connection_var_flow!(connection::Connection)
    model = connection.model
    components = _iesopt(model).model.components

    if !isnothing(connection.etdf)
        return nothing
    end

    node_from = components[connection.node_from]
    node_to = components[connection.node_to]

    if connection.is_pf_controlled[]
        if _has_representative_snapshots(model)
            @critical "Representative Snapshots are currently not supported for models using Powerflow"
        end

        # This is a passive Conection.
        @simd for t in _iesopt(model).model.T
            # Construct the flow expression.
            JuMP.add_to_expression!(connection.exp.pf_flow[t], node_from.var.pf_theta[t], 1.0 / connection.pf_X)
            JuMP.add_to_expression!(connection.exp.pf_flow[t], node_to.var.pf_theta[t], -1.0 / connection.pf_X)

            # Connect to correct nodes.
            JuMP.add_to_expression!(node_from.exp.injection[t], connection.exp.pf_flow[t], -1)
            JuMP.add_to_expression!(node_to.exp.injection[t], connection.exp.pf_flow[t], 1)
        end
    else
        # This is a controllable Connection.

        # Construct the flow variable.
        if !_has_representative_snapshots(model)
            connection.var.flow = @variable(
                model,
                [t = _iesopt(model).model.T],
                base_name = _base_name(connection, "flow"),
                container = Array
            )
        else
            # Create all representatives.
            _repr = Dict(
                t => @variable(model, base_name = _base_name(connection, "flow[$(t)]")) for
                t in _iesopt(model).model.T if _iesopt(model).model.snapshots[t].is_representative
            )

            # Create all variables, either as themselves or their representative.
            connection.var.flow = collect(
                _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[_iesopt(model).model.snapshots[t].representative] for t in _iesopt(model).model.T
            )
        end

        # Connect to correct nodes.
        loss = something(connection.loss, 0)
        @simd for t in _iesopt(model).model.T
            JuMP.add_to_expression!(components[connection.node_from].exp.injection[t], -connection.var.flow[t])
            JuMP.add_to_expression!(
                components[connection.node_to].exp.injection[t],
                connection.var.flow[t],
                1 - _get(loss, t),
            )
        end
    end

    return nothing
end
