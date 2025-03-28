@doc raw"""
    _profile_var_aux_value!(profile::Profile)

Add the variable that is used in this `Profile`s value to `profile.model`.

The variable `var_value[t]` is constructed and is linked to the correct `Node`s. There are different ways, IESopt
interprets this, based on the setting of `profile.mode`:

1. **fixed**: The value is already handled by the constant term of `profile.exp.value` and NO variable is constructed.
2. **create**, **destroy**, or **ranged**: This models the creation or destruction of energy - used mainly to represent
   model boundaries, and energy that comes into the model or leaves the model's scope. It is however important that
   `create` should mostly be used feeding into a `Node` (`profile.node_from = nothing`) and
   `destroy` withdrawing from a `Node` (`profile.node_to = nothing`). If `lb` and `ub` are defined, `ranged` can be used
   that allows a more detailed control over the `Profile`, specifying upper and lower bounds for every `Snapshot`. See
   `_profile_con_value_bounds!(profile::Profile)` for details on the specific bounds for each case.

This variable is added to the `profile.exp.value`. Additionally, the energy (that `profile.exp.value` represents)
gets "injected" at the `Node`s that the `profile` is connected to, resulting in
```math
\begin{aligned}
   & \text{profile.node}_{from}\text{.injection}_t = \text{profile.node}_{from}\text{.injection}_t - \text{value}_t, \qquad \forall t \in T \\
   & \text{profile.node}_{to}\text{.injection}_t = \text{profile.node}_{to}\text{.injection}_t + \text{value}_t, \qquad \forall t \in T
\end{aligned}
```
"""
function _profile_var_aux_value!(profile::Profile)
    model = profile.model

    if profile.mode === :fixed
        # This Profile's value is already added to the value expression. Nothing to do here.
    else
        # Create the variable.
        if !_has_representative_snapshots(model)
            profile.var.aux_value = @variable(
                model,
                [t = get_T(model)],
                base_name = make_base_name(profile, "aux_value"),
                container = Array
            )
        else
            # Create all representatives.
            _repr = Dict(
                t => @variable(model, base_name = make_base_name(profile, "aux_value[$(t)]")) for
                t in get_T(model) if internal(model).model.snapshots[t].is_representative
            )

            # Create all variables, either as themselves or their representative.
            profile.var.aux_value = collect(
                internal(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[internal(model).model.snapshots[t].representative] for t in get_T(model)
            )
        end

        if (profile.mode === :create) || (profile.mode === :destroy)
            # Properly set the lower bound.
            JuMP.set_lower_bound.(profile.var.aux_value, 0)
        end

        # Add it to the expression.
        JuMP.add_to_expression!.(profile.exp.value, profile.var.aux_value)
    end

    return nothing
end
