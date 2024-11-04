@doc raw"""
    _node_con_nodalbalance!(model::JuMP.Model, node::Node)

Add the constraint describing the nodal balance to the `model`.

Depending on whether the `node` is stateful or not, this constructs different representations:

> `if node.has_state == true`
> ```math
> \begin{aligned}
>     & \text{state}_t = \text{state}_{t-1} \cdot \text{factor}^\omega_{t-1} + \text{injection}_{t-1} \cdot \omega_{t-1}, \qquad \forall t \in T \setminus \{1\} \\
>     \\
>     & \text{state}_1 = \text{state}_{end} \cdot \text{factor}^\omega_{end} + \text{injection}_{end} \cdot \omega_{end}
> \end{aligned}
> ```

Here $\omega_t$ is the `weight` of `Snapshot` `t`, and $\text{factor}$ is either `1.0` (if there are now percentage
losses configured), or `(1.0 - node.state_percentage_loss)` otherwise. ``\text{injection}_{t}`` describes the overall
injection (all feed-ins minus all withdrawals). ``end`` indicates the last snapshot in ``T``. Depending on the setting
of `state_cyclic` the second constraint is written as ``=`` (`"eq"`) or ``\leq`` (`"leq"`). The latter allows the
destruction of excess energy at the end of the total time period to help with feasibility.

> `if node.has_state == false`
> ```math
> \begin{aligned}
>     & \text{injection}_{t} = 0, \qquad \forall t \in T \\
> \end{aligned}
> ```

This equation can further be configured using the `nodal_balance` parameter, which accepts `enforce` (resulting in
``=``), `create` (resulting in ``\leq``; allowing the creation of energy - or "negative injections"), and `destroy` (
resulting in ``\geq``; allowing the destruction of energy - or "positive injections"). This can be used to model some
form of energy that can either be sold (using a `destroy` `Profile` connected to this `Node`), or "wasted into the air"
using the `destroy` setting of this `Node`. 
"""
function _node_con_nodalbalance!(node::Node)
    if !isnothing(node.etdf_group)
        return nothing
    end

    model = node.model

    if node.has_state
        factor = isnothing(node.state_percentage_loss) ? 1.0 : (1.0 - node.state_percentage_loss)

        for t in get_T(model)
            if (t == 1) && (node.state_cyclic === :disabled)
                # If state_cyclic is disabled, we skip the basic state calculation. But in order to make sure that
                # any amount of energy exchanged in the last snapshot, we use the special constraint for t=1
                # to still cap that using the upper/lower bound. This is handled in `constr_last_state.jl`.
                node.con.nodalbalance[1] = @constraint(model, 0 == 0)
                # The above "dummy" constraint is only used to make sure that the first entry in the array is not empty,
                # which would lead to an error in result extraction.
                continue
            end

            t_other = t == 1 ? get_T(model)[end] : (t - 1)
            injection_t_other = _iesopt(model).model.snapshots[t_other].representative

            if (t == 1) && (node.state_cyclic === :geq)
                if node.nodal_balance === :create
                    @warn "Setting `nodal_balance = create` for Nodes with `state_cyclic = geq` may not be what you want" node =
                        node.name
                end

                node.con.nodalbalance[t] = @constraint(
                    model,
                    node.var.state[t] <=
                    node.var.state[t_other] * (factor^_weight(model, t_other)) +
                    node.exp.injection[injection_t_other] * _weight(model, t_other),
                    base_name = _base_name(node, "nodalbalance", t)
                )
            elseif (t == 1) && (node.state_cyclic === :leq)
                if node.nodal_balance === :destroy
                    @warn "Setting `nodal_balance = destroy` for Nodes with `state_cyclic = leq` may not be what you want" node =
                        node.name
                end

                node.con.nodalbalance[t] = @constraint(
                    model,
                    node.var.state[t] >=
                    node.var.state[t_other] * (factor^_weight(model, t_other)) +
                    node.exp.injection[injection_t_other] * _weight(model, t_other),
                    base_name = _base_name(node, "nodalbalance", t)
                )
            else
                if node.nodal_balance === :enforce
                    # TODO: catch "weight = 1.0", since we can then turn off the multiplications!
                    e = JuMP.AffExpr(0.0)
                    JuMP.add_to_expression!(e, node.var.state[t_other]::JuMP.VariableRef, (factor^_weight(model, t_other))::Float64)
                    JuMP.add_to_expression!(e, node.exp.injection[injection_t_other]::JuMP.AffExpr, _weight(model, t_other)::Float64)
                    JuMP.add_to_expression!(e, node.var.state[t]::JuMP.VariableRef, -1.0)
                    node.con.nodalbalance[t] = @constraint(model, e == 0.0, base_name = _base_name(node, "nodalbalance", t))
                    # node.con.nodalbalance[t] = @constraint(
                    #     model,
                    #     node.var.state[t] ==
                    #     node.var.state[t_other] * (factor^_weight(model, t_other)) +
                    #     node.exp.injection[injection_t_other] * _weight(model, t_other),
                    #     base_name = _base_name(node, "nodalbalance", t)
                    # )
                elseif node.nodal_balance === :create
                    # TODO: reformulate as above
                    node.con.nodalbalance[t] = @constraint(
                        model,
                        node.var.state[t] >=
                        node.var.state[t_other] * (factor^_weight(model, t_other)) +
                        node.exp.injection[injection_t_other] * _weight(model, t_other),
                        base_name = _base_name(node, "nodalbalance", t)
                    )
                elseif node.nodal_balance === :destroy
                    # TODO: reformulate as above
                    node.con.nodalbalance[t] = @constraint(
                        model,
                        node.var.state[t] <=
                        node.var.state[t_other] * (factor^_weight(model, t_other)) +
                        node.exp.injection[injection_t_other] * _weight(model, t_other),
                        base_name = _base_name(node, "nodalbalance", t)
                    )
                end
            end
        end
    elseif node.nodal_balance === :enforce
        if !_has_representative_snapshots(model)
            nei = node.exp.injection::Vector{JuMP.AffExpr}
            w = _weight.(model, get_T(model))
            e = @expression(model, w .* nei)  # TODO: catch "weight = 1.0", since we can then turn off the multiplications!
            node.con.nodalbalance = @constraint(model, e .== 0.0, base_name = _base_name(node, "nodalbalance"))
            # node.con.nodalbalance = @constraint(
            #     model,
            #     [t = get_T(model)],
            #     _weight(model, t) * node.exp.injection[t] == 0,
            #     base_name = _base_name(node, "nodalbalance"),
            #     container = Array
            # )
        else
            # Create all representatives.
            _repr = Dict(
                t => @constraint(
                    model,
                    _weight(model, t) * node.exp.injection[t] == 0,
                    base_name = _base_name(node, "nodalbalance", t)
                ) for t in get_T(model) if _iesopt(model).model.snapshots[t].is_representative
            )

            # Create all constraints, either as themselves or their representative.
            node.con.nodalbalance = collect(
                _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[_iesopt(model).model.snapshots[t].representative] for t in get_T(model)
            )
        end
    elseif node.nodal_balance === :create
        # TODO: reformulate as above
        if !_has_representative_snapshots(model)
            node.con.nodalbalance = @constraint(
                model,
                [t = get_T(model)],
                _weight(model, t) * node.exp.injection[t] <= 0,
                base_name = _base_name(node, "nodalbalance"),
                container = Array
            )
        else
            # Create all representatives.
            _repr = Dict(
                t => @constraint(
                    model,
                    _weight(model, t) * node.exp.injection[t] <= 0,
                    base_name = _base_name(node, "nodalbalance[$(t)]")
                ) for t in get_T(model) if _iesopt(model).model.snapshots[t].is_representative
            )

            # Create all constraints, either as themselves or their representative.
            node.con.nodalbalance = collect(
                _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[_iesopt(model).model.snapshots[t].representative] for t in get_T(model)
            )
        end
    elseif node.nodal_balance === :destroy
        # TODO: reformulate as above
        if !_has_representative_snapshots(model)
            node.con.nodalbalance = @constraint(
                model,
                [t = get_T(model)],
                _weight(model, t) * node.exp.injection[t] >= 0,
                base_name = _base_name(node, "nodalbalance"),
                container = Array
            )
        else
            # Create all representatives.
            _repr = Dict(
                t => @constraint(
                    model,
                    _weight(model, t) * node.exp.injection[t] >= 0,
                    base_name = _base_name(node, "nodalbalance[$(t)]")
                ) for t in get_T(model) if _iesopt(model).model.snapshots[t].is_representative
            )

            # Create all constraints, either as themselves or their representative.
            node.con.nodalbalance = collect(
                _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[_iesopt(model).model.snapshots[t].representative] for t in get_T(model)
            )
        end
    elseif node.nodal_balance === :sum
        # TODO: reformulate as above
        T = get_T(model)[end]
        begin_steps = [t for t in 1:(node.sum_window_step):T if (t - 1 + node.sum_window_size) <= T]
        node.con.nodalbalance = @constraint(
            model,
            [t0 = begin_steps],
            sum(_weight(model, t) * node.exp.injection[t] for t in t0:(t0 - 1 + node.sum_window_size)) == 0,
            base_name = _base_name(node, "nodalbalance"),
            container = Array
        )
    end
end
