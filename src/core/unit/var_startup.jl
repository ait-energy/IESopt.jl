@doc raw"""
    _unit_var_startup!(model::JuMP.Model, unit::Unit)

Add the variable describing the per-snapshot startup to the `model`.

This adds a variable per snapshot to the model (if the respective setting `unit.unit_commitment` is activated).
The variable can be further parameterized using the `unit.unit_commitment` setting ("linear", "binary", "integer"). It
will automatically enforce the constraints ``0 \leq \text{startup} \leq \text{unitcount}``, with ``\text{unitcount}``
describing the number of units that are aggregated in this `unit` (set by `unit.unit_count`). This
describes the startup that happens during the current snapshot and can be accessed via `unit.var.startup`.
"""
function _unit_var_startup!(unit::Unit)
    if isnothing(unit.startup_cost) || (unit.unit_commitment === :off)
        return nothing
    end

    model = unit.model

    if !_has_representative_snapshots(model)
        unit.var.startup = @variable(
            model,
            [t = get_T(model)],
            # This will automatically be binary/integer valued as soon as `var_ison` is.
            # binary=(unit.unit_commitment === :binary), integer=(unit.unit_commitment === :integer),
            lower_bound = 0.0,
            base_name = make_base_name(unit, "startup"),
            container = Array
        )
    else
        # Create all representatives.
        _repr = Dict(
            t => @variable(model, lower_bound = 0.0, base_name = make_base_name(unit, "startup[$(t)]")) for
            t in get_T(model) if internal(model).model.snapshots[t].is_representative
        )

        # Create all variables, either as themselves or their representative.
        unit.var.startup = collect(
            internal(model).model.snapshots[t].is_representative ? _repr[t] :
            _repr[internal(model).model.snapshots[t].representative] for t in get_T(model)
        )
    end

    return nothing
end
