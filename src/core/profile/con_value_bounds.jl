@doc raw"""
    _profile_con_value_bounds!(model::JuMP.Model, profile::Profile)

Add the constraint defining the bounds of this `profile` to the `model`.

This heavily depends on the `mode` setting, as
it does nothing if the `mode` is set to `fixed`, or the `value` is actually controlled by an `Expression`.
The variable can be accessed via `profile.var.aux_value[t]`, but using the normal result extraction is recommended,
since that properly handles the `profile.exp.value` instead.

Otherwise:

> `if profile.mode === :create or profile.mode === :destroy`
> ```math
> \begin{aligned}
>     & \text{aux_value}_t \geq 0, \qquad \forall t \in T
> \end{aligned}
> ```

> `if profile.mode === :ranged`
> ```math
> \begin{aligned}
>     & \text{value}_t \geq \text{lb}_t, \qquad \forall t \in T \\
>     & \text{value}_t \leq \text{ub}_t, \qquad \forall t \in T
> \end{aligned}
> ```

Here, `lb` and `ub` can be left empty, which drops the respective constraint.
"""
function _profile_con_value_bounds!(profile::Profile)
    model = profile.model

    if profile.mode === :fixed
        # Since the whole Profile "value" is already handled, we do not need to constraint it.
        return nothing
    end

    # Constrain the `value` based on the setting of `mode`.
    if profile.mode === :ranged
        if !isnothing(profile.lb)
            if !_has_representative_snapshots(model)
                profile.con.value_lb = @constraint(
                    model,
                    [t = _iesopt(model).model.T],
                    profile.var.aux_value[t] >= _get(profile.lb, t),
                    base_name = _base_name(profile, "value_lb"),
                    container = Array
                )
            else
                # Create all representatives.
                _repr = Dict(
                    t => @constraint(
                        model,
                        profile.var.aux_value[t] >= _get(profile.lb, t),
                        base_name = _base_name(profile, "value_lb[$(t)]")
                    ) for t in _iesopt(model).model.T if _iesopt(model).model.snapshots[t].is_representative
                )

                # Create all constraints, either as themselves or their representative.
                profile.con.value_lb = collect(
                    _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                    _repr[_iesopt(model).model.snapshots[t].representative] for t in _iesopt(model).model.T
                )
            end
        end
        if !isnothing(profile.ub)
            if !_has_representative_snapshots(model)
                profile.con.value_ub = @constraint(
                    model,
                    [t = _iesopt(model).model.T],
                    profile.var.aux_value[t] <= _get(profile.ub, t),
                    base_name = _base_name(profile, "value_ub"),
                    container = Array
                )
            else
                # Create all representatives.
                _repr = Dict(
                    t => @constraint(
                        model,
                        profile.var.aux_value[t] <= _get(profile.ub, t),
                        base_name = _base_name(profile, "value_ub[$(t)]")
                    ) for t in _iesopt(model).model.T if _iesopt(model).model.snapshots[t].is_representative
                )

                # Create all constraints, either as themselves or their representative.
                profile.con.value_ub = collect(
                    _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                    _repr[_iesopt(model).model.snapshots[t].representative] for t in _iesopt(model).model.T
                )
            end
        end
    end

    return nothing
end
