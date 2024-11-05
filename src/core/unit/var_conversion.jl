# Note: This file relies on the successful creation of the `var_ison` => functions need to be called after that.

@doc raw"""
    _unit_var_conversion!(model::JuMP.Model, unit::Unit)

Add the variable describing the `unit`'s conversion to the `model`.

This can be accessed via `unit.var.conversion[t]`; this does not describe the full output of the `Unit` since that maybe
also include fixed generation based on the `ison` variable.

!!! info
    This applies some heavy recalculation of efficiencies to account for minimum load and so on, that are currently not
    fully documented. This essentially comes down to the following: As long as minimum load is not enabled, that is
    rather simple (using the conversion expression to withdraw energy from the inputs and push energy into the outputs).
    If a separate minimum load conversion is specified it results in the following: (1) if running at minimum load the
    supplied minimum load conversion will be used; (2) if running at maximum capacity the "normal" conversion expression
    will be used; (3) for any point in-between a linear interpolation scales up all coefficients of the conversion
    expression to "connect" case (1) and (2).
"""
function _unit_var_conversion!(unit::Unit)
    model = unit.model

    if !_has_representative_snapshots(model)
        unit.var.conversion = @variable(
            model,
            [t = get_T(model)],
            lower_bound = 0,
            base_name = _base_name(unit, "conversion"),
            container = Array
        )
    else
        # Create all representatives.
        _repr = Dict(
            t => @variable(model, lower_bound = 0, base_name = _base_name(unit, "conversion[$(t)]")) for
            t in get_T(model) if _iesopt(model).model.snapshots[t].is_representative
        )

        # Create all variables, either as themselves or their representative.
        unit.var.conversion = collect(
            _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
            _repr[_iesopt(model).model.snapshots[t].representative] for t in get_T(model)
        )
    end

    return _unit_var_conversion_connect!(unit)
end

function _unit_var_conversion_connect!(unit::Unit)
    # Pre-calculate the Unit's conversion limits once.
    limits = _unit_capacity_limits(unit)

    # Properly connect in- and outputs based on conversion rule.
    if isnothing(unit.conversion_at_min)
        _unit_var_conversion_connect!(unit, limits)
    else
        incremental_efficiencies = Dict(
            dir => Dict(
                carrier => (
                    (value .- unit.min_conversion .* unit.conversion_at_min_dict[dir][carrier]) ./
                    (1.0 - unit.min_conversion)
                ) for (carrier, value) in unit.conversion_dict[dir]
            ) for dir in [:in, :out]
        )
        _unit_var_conversion_connect!(unit, limits, incremental_efficiencies)
    end

    return nothing
end

function _unit_var_conversion_connect!(unit::Unit, limits::Dict, incremental_efficiencies::Dict)
    model = unit.model
    components = _iesopt(model).model.components

    # TODO: re-order this for loop like in the function below
    for t in get_T(model)
        _iesopt(model).model.snapshots[t].is_representative || continue

        for carrier in keys(unit.conversion_dict[:in])
            _total(unit, :in, carrier.name)[t] = (
                _get(unit.conversion_at_min_dict[:in][carrier], t) *
                limits[:min][t] *
                access(unit.capacity, t, NonEmptyScalarExpressionValue) +
                _get(incremental_efficiencies[:in][carrier], t) * unit.var.conversion[t]
            )
            JuMP.add_to_expression!(
                components[unit.inputs[carrier]].exp.injection[t],
                _total(unit, :in, carrier.name)[t],
                -1.0,
            )
        end

        for carrier in keys(unit.conversion_dict[:out])
            _total(unit, :out, carrier.name)[t] = (
                _get(unit.conversion_at_min_dict[:out][carrier], t) *
                limits[:min][t] *
                access(unit.capacity, t, NonEmptyScalarExpressionValue) +
                _get(incremental_efficiencies[:out][carrier], t) * unit.var.conversion[t]
            )
            JuMP.add_to_expression!(
                components[unit.outputs[carrier]].exp.injection[t],
                _total(unit, :out, carrier.name)[t],
            )
        end
    end

    return nothing
end

function _unit_var_conversion_connect!(unit::Unit, limits::Dict)
    # There is just a single efficiency to care about.
    model = unit.model

    components = _iesopt(model).model.components
    unit_var_conversion = unit.var.conversion

    input_totals = Dict{Carrier, Vector{JuMP.AffExpr}}(
        carrier => _total(unit, :in, carrier.name) for carrier in keys(unit.conversion_dict[:in])
    )
    output_totals = Dict{Carrier, Vector{JuMP.AffExpr}}(
        carrier => _total(unit, :out, carrier.name) for carrier in keys(unit.conversion_dict[:out])
    )

    _a = collect(_get(limits[:min], t) for t in get_T(model))
    _b = collect(access(unit.capacity, t) for t in get_T(model))
    # TODO: this should be avoidable by doing unit.var.conversion?
    _c::Vector{JuMP.VariableRef} = unit.var.conversion

    _mode::Symbol, _term1::Vector{JuMP.AffExpr}, _term2::Vector{Float64} = (
        if _a[1] isa Number
            if _b[1] isa Number
                (:single, Vector{JuMP.AffExpr}(), convert.(Float64, _a .* _b))
            else
                (:multi, _b, convert.(Float64, _a))
            end
        elseif _b[1] isa Number
            (:multi, _a, convert.(Float64, _b))
        else
            @critical "Fatal error"
        end
    )

    _snapshots = _iesopt(model).model.snapshots
    _T = (
        _has_representative_snapshots(model) ? [t for t in get_T(model) if _snapshots[t].is_representative] :
        get_T(model)
    )::Vector{_ID}

    for (carrier, mult) in unit.conversion_dict[:in]
        _inpinj = components[unit.inputs[carrier]].exp.injection::Vector{JuMP.AffExpr}
        for t in _T
            _inpinj_t = _inpinj[t]::JuMP.AffExpr

            # (_get(limits[:min], t) * _get(unit.capacity, t) + unit.var.conversion[t]) * _get(mult, t)
            # = (a*b + c) * d
            _d = _get(mult, t)::Float64
            _expr = input_totals[carrier][t]::JuMP.AffExpr
            _coeff = (_d * _term2[t])::Float64

            JuMP.add_to_expression!(_expr, _c[t], _d)
            JuMP.add_to_expression!(_inpinj_t, _c[t], -_d)

            if _mode == :single
                JuMP.add_to_expression!(_expr, _coeff)
                JuMP.add_to_expression!(_inpinj_t, -_coeff)
            else
                JuMP.add_to_expression!(_expr, _term1[t], _coeff)
                JuMP.add_to_expression!(_inpinj_t, _term1[t], -_coeff)
            end
        end
    end

    for (carrier, mult) in unit.conversion_dict[:out]
        _outinj = components[unit.outputs[carrier]].exp.injection::Vector{JuMP.AffExpr}
        for t in _T
            _outinj_t = _outinj[t]::JuMP.AffExpr

            # (_get(limits[:min], t) * _get(unit.capacity, t) + unit.var.conversion[t]) * _get(mult, t)
            # = (a*b + c) * d
            _d = _get(mult, t)::Float64
            _expr = output_totals[carrier][t]::JuMP.AffExpr
            _coeff = (_d * _term2[t])::Float64

            JuMP.add_to_expression!(_expr, _c[t], _d)
            JuMP.add_to_expression!(_outinj_t, _c[t], _d)

            if _mode == :single
                JuMP.add_to_expression!(_expr, _coeff)
                JuMP.add_to_expression!(_outinj_t, _coeff)
            else
                JuMP.add_to_expression!(_expr, _term1[t], _coeff)
                JuMP.add_to_expression!(_outinj_t, _term1[t], _coeff)
            end
        end
    end

    return nothing
end
