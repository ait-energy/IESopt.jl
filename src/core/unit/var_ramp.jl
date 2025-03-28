@doc raw"""
    _unit_var_ramp!(unit::Unit)

Add the variable describing the per-snapshot ramping to `unit.model`.

This adds two variables per snapshot to the model (if the respective setting `unit.enable_ramp_up` or
`unit.enable_ramp_down` is activated). Both are preconstructed with a fixed lower bound of `0`. This describes the
amount of change in conversion that occurs during the current snapshot. These can be accessed via `unit.var.ramp_up[t]`
and `unit.var.ramp_down[t]`.

These variables are only used for ramping **costs**. The limits are enforced directly on the conversion, which means
this variable only exists if costs are specified!
"""
function _unit_var_ramp!(unit::Unit)
    model = unit.model

    # Construct the variables.
    if unit.enable_ramp_up && !isnothing(unit.ramp_up_cost)
        unit.var.ramp_up = @variable(
            model,
            [t = get_T(model)],
            lower_bound = 0,
            base_name = make_base_name(unit, "ramp_up"),
            container = Array
        )
    end
    if unit.enable_ramp_down && !isnothing(unit.ramp_up_cost)
        unit.var.ramp_down = @variable(
            model,
            [t = get_T(model)],
            lower_bound = 0,
            base_name = make_base_name(unit, "ramp_down"),
            container = Array
        )
    end

    return nothing
end
