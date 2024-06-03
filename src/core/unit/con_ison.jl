@doc raw"""
    _unit_con_ison!(unit::Unit)

Construct the upper bound for `var_ison`, based on `unit.unit_count`, if it is handled by an external `Decision`.
"""
function _unit_con_ison!(unit::Unit)
    if (unit.unit_commitment === :off) || isa(_get(unit.unit_count), Number)
        return nothing
    end

    model = unit.model

    unit.con.ison_ub = @constraint(
        model,
        [t = _iesopt(model).model.T],
        unit.var.ison[t] <= _get(unit.unit_count),
        base_name = _base_name(unit, "ison_ub"),
        container = Array
    )

    return nothing
end
