@doc raw"""
    _unit_var_ison!(unit::Unit)

Add the variable describing the current "online" state of the `unit` to `unit.model`.

The variable can be further parameterized using the `unit.unit_commitment` setting ("linear", "binary", "integer"). It
will automatically enforce the constraints ``0 \leq \text{ison} \leq \text{unitcount}``, with ``\text{unitcount}``
describing the number of units that are aggregated in this `unit` (set by `unit.unit_count`). This can be accessed via
`unit.var.ison[t]`.
"""
function _unit_var_ison!(unit::Unit)
    (unit.unit_commitment === :off) && return

    model = unit.model

    # The lower bound `0 <= var_ison` is redundant since `0 <= var_conversion <= var_ison` holds always.
    if isa(access(unit.unit_count), Number)
        unit.var.ison = @variable(
            model,
            [t = get_T(model)],
            binary = (unit.unit_commitment === :binary),
            integer = (unit.unit_commitment === :integer),
            lower_bound = 0,
            upper_bound = access(unit.unit_count, Number),
            base_name = make_base_name(unit, "ison"),
            container = Array
        )
    else
        unit.var.ison = @variable(
            model,
            [t = get_T(model)],
            binary = (unit.unit_commitment === :binary),
            integer = (unit.unit_commitment === :integer),
            lower_bound = 0,
            base_name = make_base_name(unit, "ison"),
            container = Array
        )
    end
end
