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
    components = internal(model).model.components

    if !isnothing(connection.etdf)
        return nothing
    end

    node_from = components[connection.node_from]
    node_to = components[connection.node_to]

    if connection.is_pf_controlled[]
        if _has_representative_snapshots(model)
            @critical "Representative Snapshots are currently not supported for models using Powerflow"
        end

        # This is a passive Connection.
        @simd for t in get_T(model)
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
            connection.var.flow =
                @variable(model, [t = get_T(model)], base_name = make_base_name(connection, "flow"), container = Array)
        else
            # Create all representatives.
            _repr = Dict(
                t => @variable(model, base_name = make_base_name(connection, "flow[$(t)]")) for
                t in get_T(model) if internal(model).model.snapshots[t].is_representative
            )

            # Create all variables, either as themselves or their representative.
            connection.var.flow = collect(
                internal(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[internal(model).model.snapshots[t].representative] for t in get_T(model)
            )
        end

        # Connect to correct nodes.
        cvf = connection.var.flow::Vector{JuMP.VariableRef}
        nfei = components[connection.node_from].exp.injection::Vector{JuMP.AffExpr}
        ntei = components[connection.node_to].exp.injection::Vector{JuMP.AffExpr}
        loss = _prepare(connection.loss; default=0.0)

        Δ = internal(connection.model).model.snapshots[1].weight
        has_delay = !_isempty(connection.delay)

        @inbounds @simd for t in get_T(model)
            delayed_snapshots, delayed_weights = if !has_delay
                (t,), (1.0,)
            else
                Δi, r = divrem(access(connection.delay, t), Δ)
                mod1.(t .+ Int(Δi) .+ (0, 1), last(get_T(model))), (1 - r / Δ, r / Δ)
            end
            if connection.loss_mode === :to
                JuMP.add_to_expression!(connection.exp.in[t], cvf[t], 1.0)
                for (i, td) in enumerate(delayed_snapshots)
                    JuMP.add_to_expression!(
                        connection.exp.out[td],
                        cvf[t],
                        delayed_weights[i] * (1.0 - access(loss, t)::Float64),
                    )
                end
            elseif connection.loss_mode === :from
                JuMP.add_to_expression!(connection.exp.in[t], cvf[t], 1.0 / (1.0 - access(loss, t)::Float64))
                for (i, td) in enumerate(delayed_snapshots)
                    JuMP.add_to_expression!(connection.exp.out[td], cvf[t], delayed_weights[i])
                end
            elseif connection.loss_mode === :split
                JuMP.add_to_expression!(connection.exp.in[t], cvf[t], 1.0 / sqrt(1.0 - access(loss, t)::Float64))
                for (i, td) in enumerate(delayed_snapshots)
                    JuMP.add_to_expression!(
                        connection.exp.out[td],
                        cvf[t],
                        delayed_weights[i] * sqrt(1.0 - access(loss, t)::Float64),
                    )
                end
            end
        end

        @inbounds @simd for t in get_T(model)
            JuMP.add_to_expression!(nfei[t], connection.exp.in[t], -1.0)
            JuMP.add_to_expression!(ntei[t], connection.exp.out[t], 1.0)
        end
    end

    return nothing
end
