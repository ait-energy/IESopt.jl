@doc raw"""
    _unit_con_ison!(unit::Unit)

Construct the upper bound for `var_ison`, based on `unit.unit_count`, if it is handled by an external `Decision`.
"""
function _unit_con_ison!(unit::Unit)
    if (unit.unit_commitment === :off) || isa(access(unit.unit_count), Number)
        return nothing
    end

    model = unit.model

    unit.con.ison_ub = @constraint(
        model,
        [t = get_T(model)],
        unit.var.ison[t] <= access(unit.unit_count, NonEmptyScalarExpressionValue),
        base_name = make_base_name(unit, "ison_ub"),
        container = Array
    )

    return nothing
end
