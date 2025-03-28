@doc raw"""
    _profile_obj_cost!(profile::Profile)

Add the (potential) cost of this `Profile` to the global objective function.

The `profile.cost` setting specifies a potential cost for the creation ("resource costs", i.e. importing gas into the
model) or destruction ("penalties", i.e. costs linked to the emission of CO2). It can have a unique value for every
`Snapshot`, i.e. allowing to model a time-varying gas price throughout the year.

The contribution to the global objective function is as follows:
```math
\sum_{t\in T} \text{value}_t \cdot \text{profile.cost}_t \cdot \omega_t
```

Here $\omega_t$ is the `weight` of `Snapshot` `t`, and ``\text{value}_t`` actually refers to the value of
`profile.exp.value[t]` (and not only on the maybe non-existing variable).
"""
function _profile_obj_cost!(profile::Profile)
    if _isempty(profile.cost)
        return nothing
    end

    model = profile.model

    # todo: this is inefficient: we are building up an AffExpr to add it to the objective; instead: add each term
    # todo: furthermore, this always calls VariableRef * Float, which is inefficient, and could be done in add_to_expression
    profile.obj.cost = JuMP.AffExpr(0.0)
    for t in get_T(model)
        JuMP.add_to_expression!(
            profile.obj.cost,
            profile.exp.value[t],
            _weight(model, t) * access(profile.cost, t, Float64),
        )
    end

    push!(internal(model).model.objectives["total_cost"].terms, profile.obj.cost)

    return nothing
end
