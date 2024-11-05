"""
A `Unit` allows transforming one (or many) forms of energy into another one (or many), given some constraints and costs.

!!! details "Basic Examples"
    A `Unit` that represents a basic gas turbine:
    ```yaml
    gas_turbine:
      type: Unit
      inputs: {gas: gas_grid}
      outputs: {electricity: node, co2: total_co2}
      conversion: 1 gas -> 0.4 electricity + 0.2 co2
      capacity: 10 out:electricity
    ```
    A `Unit` that represents a basic wind turbine:
    ```yaml
    wind_turbine:
      type: Unit
      outputs: {electricity: node}
      conversion: ~ -> 1 electricity
      capacity: 10 out:electricity
      availability_factor: wind_factor@input_data
      marginal_cost: 1.7 per out:electricity
    ```
    A `Unit` that represents a basic heat pump, utilizing a varying COP:
    ```yaml
    heatpump:
      type: Unit
      inputs: {electricity: grid}
      outputs: {heat: heat_system}
      conversion: 1 electricity -> cop@inputfile heat
      capacity: 10 in:electricity
    ```
"""
@kwdef struct Unit <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    constraint_safety::Bool
    constraint_safety_cost::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String

    raw"""```{"mandatory": "yes", "values": "string", "unit": "-", "default": "-"}```
    The conversion expression describing how this `Unit` transforms energy. Specified in the form of "$\alpha \cdot
    carrier_1 + \beta \cdot carrier_2$ -> $\gamma \cdot carrier_3 + \delta \cdot carrier_4$". Coefficients allow simple
    numerical calculations, but are not allowed to include spaces (so e.g. `(1.0/9.0)` is valid). Coefficients are
    allowed to be `NumericalInput`s, resulting in `column@data_file` being a valid coefficient (this can be used e.g.
    for time-varying COPs of heatpumps).
    """
    conversion::_String

    raw"""```{"mandatory": "yes", "values": "value dir:carrier", "unit": "-", "default": "-"}```
    Maximum capacity of this `Unit`, to be given in the format `X in/out:carrier` where `X` is the amount, `in` or `out`
    (followed by `:`) specifies whether the limit is to be placed on the in- our output of this `Unit`, and `carrier`
    specifies the respective `Carrier`. Example: `100 in:electricity` (to limit the "input rating").
    """
    capacity::Expression

    raw"""```{"mandatory": "yes", "values": "dict", "unit": "-", "default": "-"}```
    Dictionary specifying the output "ports" of this `Unit`. Refer to the basic examples for the general syntax.
    """
    outputs::Dict{Carrier, String} = Dict()

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    raw"""```{"mandatory": "no", "values": "dict", "unit": "-", "default": "-"}```
    Dictionary specifying the input "ports" of this `Unit`. If not specified (= no explicit input), the `conversion` has
    to follow the form of `conversion: ~ -> ...`, indicating an "open" input. This may, e.g., be used for renewable
    energy sources, where the primary energy input (e.g., solar) is not explicitly modeled. 
    """
    inputs::Dict{Carrier, String} = Dict()

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "power", "default": "``+\\infty``"}```
    Time series (or fixed value) that limits the available capacity. If, e.g., `capacity: 100 out:electricity` and
    `availability: 70`, the available capacity will only be `70 electricity`. Can be used to model non-availability of
    power plants, e.g., due to maintenance. For time-varying availability of intermittent generators (e.g., wind), it's
    recommended (most of the time) to use `availability_factor` instead.
    """
    availability::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "``\\in [0, 1]``", "unit": "-", "default": "`1`"}```
    Similar to `availability`, but given as factor of `capacity` instead. If, e.g., `capacity: 100 out:electricity` and
    `availability_factor: 0.7`, the available capacity will only be `70 electricity`. This is especially useful for
    intermittent generators, where the availability is not a fixed value, but depends on the weather, and can be passed,
    e.g., by setting `availability_factor: wind@input_data_file`.
    """
    availability_factor::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "`true`, `false`", "unit": "-", "default": "`false`"}```
    If `true`, the minimal partial load will be influenced by the availability. Example: Consider a `Unit` with
    `capacity: 100 out:electricity`, a `min_conversion` of `0.4`, and an `availability_factor` of `0.5`. This entails
    having `50 electricity` available, while the minimal partial load is `40 electricity`. This results in the `Unit` at
    best operating only closely above the minimal partial load. Furthermore, an `availability_factor` below `0.4` would
    result in no feasible generation, besides shutting the `Unit` off. While this might be the intended mode of
    operation in many use cases, `adapt_min_to_availability` can change this: If set to `true`, this dynamically changes
    the minimal partial load. In the previous example, that means `(100 * 0.5) * 0.4 = 20 electricity` (the 50% minimum
    load are now based on the available 40), changing the overall behaviour (including efficiencies) as well as leading
    to feasible generations even when the `availability_factor` is below `0.4`.
    """
    adapt_min_to_availability::Bool = false

    raw"""```{"mandatory": "no", "values": "`value per dir:carrier`", "unit": "monetary per energy", "default": "`0`"}```
    Marginal cost of the consumption/generation of one unit of energy of the specified carrier. Has to be given in the
    format `value per dir:carrier`, e.g. `3.5 per out:electricity` for a marginal cost of 3.5 monetary units per unit of
    electricity generated.
    """
    marginal_cost::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "`true`, `false`", "unit": "-", "default": "`false`"}```
    Enables calculation of upward ramps. Ramping is based on the carrier specified in `capacity`.
    """
    enable_ramp_up::Bool = false

    raw"""```{"mandatory": "no", "values": "`true`, `false`", "unit": "-", "default": "`false`"}```
    Enables calculation of downward ramps. Ramping is based on the carrier specified in `capacity`.
    """
    enable_ramp_down::Bool = false

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "monetary per power", "default": "`0`"}```
    Sets the cost of ramping up (increasing in-/output) by 1 unit of the capacity carrier.
    """
    ramp_up_cost::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "monetary per power", "default": "`0`"}```
    Sets the cost of ramping down (decreasing in-/output) by 1 unit of the capacity carrier.
    """
    ramp_down_cost::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "``\\in [0, 1]``", "unit": "-", "default": "`1`"}```
    Limits the allowed ramping up based on this factor of the total capacity. If `capacity: 100 in:electricity` with
    `ramp_up_limit: 0.2`, this limits the total increase of usage of electricity (on the input) to 20 units (power) per
    hour. For example, starting at an input of 35, after one hour the input has to be lesser than or equal to 55. If a
    `Snapshot`'s duration is set to, e.g., two hours, this would allow a total increase of 40 units.
    """
    ramp_up_limit::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "``\\in [0, 1]``", "unit": "-", "default": "`1`"}```
    Limits the allowed ramping down based on this factor of the total capacity. See `ramp_up_limit`.
    """
    ramp_down_limit::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "hours", "default": "`0`"}```
    Minimum on-time of the `Unit`. If set, the `Unit` has to be on for at least this amount of time, after turning on.
    It is highly recommended to only use this with `unit_commitment: binary`, unless you know why it's fine to use with
    another mode.
    """
    min_on_time::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "hours", "default": "`0`"}```
    Minimum off-time of the `Unit`. If set, the `Unit` has to be off for at least this amount of time, after turning
    off. It is highly recommended to only use this with `unit_commitment: binary`, unless you know why it's fine to use
    with another mode. 
    """
    min_off_time::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "hours", "default": "`0`"}```
    Time that this `Unit` has already been running before the optimization starts. Can be used in combination with
    `min_on_time`.
    """
    on_time_before::_ScalarInput = 0

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "hours", "default": "`0`"}```
    Time that this `Unit` has already been off before the optimization starts. Can be used in combination with
    `min_off_time`.
    """
    off_time_before::_ScalarInput = 0

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`1`"}```
    Number of `Unit`s that should be considered to have been running before the optimization starts. Can be used in
    combination with `on_time_before`, especially for `unit_count` greater than 1.
    """
    is_on_before::_ScalarInput = 1        # todo: why is this a bound (and not _OptionalScalarInput)

    raw"""```{"mandatory": "no", "values": "`off`, `linear`, `binary`, `integer`", "unit": "-", "default": "`off`"}```
    Controls how the unit commitment of this `Unit` is handled. `linear` results in the ability to startup parts of the
    unit (so `0.314159` is a feasible amount of "turned on unit"), while `binary` restricts the `Unit` to either be on
    (converting the `conversion_at_min` + possible additional conversion above that minimum) or off (converting
    nothing); `integer` is needed to consider `binary` unit commitment for `Unit`s with more than 1 "grouped unit" (see
    `unit_count`).
    """
    unit_commitment::Symbol = :off

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`1`"}```
    Number of units aggregated in this `Unit`. Besides interacting with the mode of `unit_commitment`, this mainly is
    responsible for scaling the output (e.g. grouping 47 of the same wind turbine, ...).
    """
    unit_count::Expression  # default=1 is enforced in `parser.jl`

    raw"""```{"mandatory": "no", "values": "``\\in [0, 1]``", "unit": "-", "default": "-"}```
    If `unit_commitment` is not set to `off`, this specifies the percentage that is considered to be the minimal
    feasible partial load this `Unit` can operate at. Operating below that setpoint is not allowed, at that point the
    `conversion_at_min` coefficients are used, and above that they are scaled to result in `conversion` when running at
    full capacity.
    """
    min_conversion::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "string", "unit": "-", "default": "-"}```
    The conversion expression while running on the minimal partial load. Only applicable if `unit_commitment` is not
    `off` and `min_conversion` is explicitly set. Follows the same form as `conversion`.
    """
    conversion_at_min::_OptionalString = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "monetary per start", "default": "`0`"}```
    Costs per startup (also applicable if startups are not binary or integer). This is necessary to allow
    `conversion_at_min` to have (at least partially) the effect that one expects, if `unit_commitment: linear`.
    """
    startup_cost::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`0`"}```
    Priority for the build order of components. Components with higher build_priority are built before.
    This can be useful for addons, that connect multiple components and rely on specific components being initialized
    before others.
    """
    build_priority::_OptionalScalarInput = nothing

    # [Internal] =======================================================================================================
    conversion_dict::Dict{Symbol, Dict{Carrier, NonEmptyNumericalExpressionValue}} = Dict(:in => Dict(), :out => Dict())
    conversion_at_min_dict::Dict{Symbol, Dict{Carrier, NonEmptyNumericalExpressionValue}} =
        Dict(:in => Dict(), :out => Dict())

    capacity_carrier::NamedTuple{(:inout, :carrier), Tuple{Symbol, Carrier}}
    marginal_cost_carrier::Union{Nothing, NamedTuple{(:inout, :carrier), Tuple{Symbol, Carrier}}} = nothing

    # [External] =======================================================================================================
    # results::Union{Dict, Nothing} = nothing

    # [Optimization Container] =========================================================================================
    _ccoc = _CoreComponentOptContainer()
end

_result_fields(::Unit) = (:name, :inputs, :outputs, :unit_commitment)

_total(unit::Unit, direction::Symbol, carrier::AbstractString) =
    _total(unit, direction, string(carrier))::Vector{JuMP.AffExpr}
function _total(unit::Unit, direction::Symbol, carrier::String)::Vector{JuMP.AffExpr}
    if !_has_cache(unit.model, :unit_total)
        _iesopt_cache(unit.model)[:unit_total] =
            Dict{Symbol, Dict{String, Symbol}}(:in => Dict{String, Symbol}(), :out => Dict{String, Symbol}())
    end

    cache::Dict{String, Symbol} = _get_cache(unit.model, :unit_total)[direction]
    if !haskey(cache, carrier)
        cache[carrier] = Symbol("$(direction)_$(carrier)")
    end
    return unit.exp[cache[carrier]]
end

function _prepare!(unit::Unit)
    # todo: "null" in the ThermalGen component translates to "nothing" (as String) instead of nothing (as Nothing)!
    model = unit.model
    carriers = _iesopt(model).model.carriers

    # Prepare in/out total expressions.
    for carrier in keys(unit.inputs)
        _vec = Vector{JuMP.AffExpr}(undef, get_T(model)[end])
        for i in eachindex(_vec)
            _vec[i] = JuMP.AffExpr(0.0)
        end
        unit.exp[Symbol("in_$(carrier.name)")] = _vec
    end
    for carrier in keys(unit.outputs)
        _vec = Vector{JuMP.AffExpr}(undef, get_T(model)[end])
        for i in eachindex(_vec)
            _vec[i] = JuMP.AffExpr(0.0)
        end
        unit.exp[Symbol("out_$(carrier.name)")] = _vec
    end

    # Convert string formula to proper conversion dictionary.
    _convert_unit_conversion_dict!(carriers, unit)      # todo: stop passing carriers, as soon as there is unit._model

    # Normalize the conversion expressions to allow correct handling later on.
    _normalize_conversion_expressions!(unit)

    return true
end

function _isvalid(unit::Unit)
    model = unit.model

    components = _iesopt(model).model.components

    # Check that input carriers match.
    if !isnothing(unit.inputs)
        for (carrier, cname) in unit.inputs
            if carrier != components[cname].carrier
                @critical "Unit got wrong input carrier" unit = unit.name carrier = carrier input =
                    components[cname].name
            end
        end
    end

    # Check that output carriers match.
    if !isnothing(unit.outputs)
        for (carrier, cname) in unit.outputs
            if carrier != components[cname].carrier
                @critical "Unit got wrong output carrier" unit = unit.name carrier = carrier output =
                    components[cname].name
            end
        end
    end

    # Check that we can actually construct the necessary constraints.
    # todo: rework this
    # if unit.unit_commitment != :off
    #     if !isa(unit.capacity_carrier.value, _ScalarInput)
    #         for (coeff, var) in unit.capacity_carrier.value.variables
    #             if !var.comp.fixed_size
    #                 @error "Using an active <unit_commitment> as well as an endogenous capacity is currently not supported" unit =
    #                     unit.name decision = var.comp.name
    #                 return false
    #             end
    #         end
    #     end
    # end

    if !_is_milp(model) && !(unit.unit_commitment === :off || unit.unit_commitment === :linear)
        @critical "Model config only allows LP" unit = unit.name unit_commitment = unit.unit_commitment
    end

    # Warn the user of possible misconfigurations.
    if (unit.unit_commitment === :off) && (!isnothing(unit.min_conversion))
        @warn "Setting <min_conversion> while <unit_commitment> is off can lead to issues" unit = unit.name
    end

    if (unit.enable_ramp_up || unit.enable_ramp_down) && (access(unit.unit_count, Float64) != 1)
        @warn "Active ramps do not work as expected with <unit_count> different from 1" unit = unit.name
    end

    # A Unit can not be up/and down before the time horizon.
    if (unit.on_time_before != 0) && (unit.off_time_before != 0)
        @critical "A Unit can not be up and down before starting the optimization" unit = unit.name
    end

    # Check if `on_before` and `up/off_time_before` match.
    if (unit.is_on_before != 0) && (unit.off_time_before != 0)
        @critical "A Unit can not be on before the optimization and have down time" unit = unit.name
    end
    if (unit.is_on_before == 0) && (unit.on_time_before != 0)
        @critical "A Unit can not be off before the optimization and have up time" unit = unit.name
    end

    # todo: resolve the issue and then remove this
    if (access(unit.unit_count, Float64) != 1) && (!isnothing(unit.min_on_time) || !isnothing(unit.min_off_time))
        @critical "min_on_time/min_off_time is currently not supported for Units with `unit.count > 1`" unit = unit.name
    end

    # todo: resolve the issue and then remove this
    if (
        (!isnothing(unit.min_on_time) || !isnothing(unit.min_off_time)) &&
        any(_weight(model, t) != 1 for t in get_T(model)[2:end])
    )
        @warn "min_on_time/min_off_time is NOT tested for Snapshot weights != 1" unit = unit.name
    end

    if _has_representative_snapshots(model) && (unit.unit_commitment != :off)
        @critical "Active unit commitment is currently not supported for models with representative Snapshots" unit =
            unit.name
    end

    if (unit.enable_ramp_up || unit.enable_ramp_down) && _has_representative_snapshots(model)
        @critical "Enabled ramps are currently not supported while using representative Snapshots" unit = unit.name
    end

    return true
end

function _setup!(unit::Unit)
    model = unit.model

    return nothing
end

function _result(unit::Unit, mode::String, field::String; result::Int=1)
    if isnothing(findfirst("out:", field)) && isnothing(findfirst("in:", field))
        # This is not the `in:XXX` or `out:XXX` value of conversion.
        if (field == "ison") && (mode == "value") && (unit.unit_commitment != :off)
            return "$(unit.name).ison", JuMP.value.(unit.var.ison; result=result)
        end
    else
        # # This is the `in:XXX` or `out:XXX` value of conversion.
        dir, carrier = split(field, ":")
        if _has_representative_snapshots(unit.model)
            value = [
                JuMP.value(
                    _total(unit, Symbol(dir), carrier)[_iesopt(unit.model).model.snapshots[t].representative];
                    result=result,
                ) for t in get_T(unit.model)
            ]
        else
            value = JuMP.value.(_total(unit, Symbol(dir), carrier); result=result)
        end

        if mode == "value"
            return "$(unit.name).$dir.$carrier", value
        elseif mode == "sum"
            return "Unit.sum.$dir.$carrier", sum(value)
        end
    end

    @error "Unknown result extraction" unit = unit.name mode = mode field = field
    return nothing
end

include("unit/var_conversion.jl")
include("unit/var_ramp.jl")
include("unit/var_ison.jl")
include("unit/var_startup.jl")
include("unit/con_conversion_bounds.jl")
include("unit/con_ison.jl")
include("unit/con_min_onoff_time.jl")
include("unit/con_startup.jl")
include("unit/con_ramp.jl")
include("unit/con_ramp_limit.jl")
include("unit/obj_marginal_cost.jl")
include("unit/obj_startup_cost.jl")
include("unit/obj_ramp_cost.jl")

function _construct_variables!(unit::Unit)
    # Since all `Decision`s are constructed before this `Unit`, we can now properly finalize the `availability`,
    # `availability_factor`, `unit_count`, `capacity`, and `marginal_cost`.
    _finalize(unit.availability)
    _finalize(unit.availability_factor)
    _finalize(unit.unit_count)
    _finalize(unit.capacity)
    _finalize(unit.marginal_cost)

    # `var_ison` needs to be constructed before `var_conversion`
    _unit_var_ison!(unit)

    _unit_var_conversion!(unit)
    _unit_var_ramp!(unit)
    _unit_var_startup!(unit)

    return nothing
end

function _construct_constraints!(unit::Unit)
    _unit_con_conversion_bounds!(unit)
    _unit_con_ison!(unit)
    _unit_con_min_onoff_time!(unit)
    _unit_con_startup!(unit)
    _unit_con_ramp!(unit)
    _unit_con_ramp_limit!(unit)

    return nothing
end

function _construct_objective!(unit::Unit)
    _unit_obj_marginal_cost!(unit)
    _unit_obj_startup_cost!(unit)
    _unit_obj_ramp_cost!(unit)

    return nothing
end

function _convert_unit_conversion_dict!(carriers::Dict{String, Carrier}, unit::Unit)
    parsed = _convert_to_conversion_expressions(unit.model, unit.conversion)::NamedTuple
    for side in [:in, :out]
        terms = getproperty(parsed, side)
        isempty(terms) && continue

        for (carrier_str, expr) in terms
            unit.conversion_dict[side][carriers[carrier_str]] = expr.value::NonEmptyNumericalExpressionValue
        end
    end

    isnothing(unit.conversion_at_min) && return

    # Convert the optional "minconversion" conversion.
    parsed = _convert_to_conversion_expressions(unit.model, unit.conversion_at_min)::NamedTuple
    for side in [:in, :out]
        terms = getproperty(parsed, side)
        isempty(terms) && continue

        for (carrier_str, expr) in terms
            unit.conversion_at_min_dict[side][carriers[carrier_str]] = expr.value::NonEmptyNumericalExpressionValue
        end
    end

    return nothing
end

function _normalize_conversion_expressions!(unit::Unit)
    # Normalize default conversion expression.
    norm = unit.conversion_dict[unit.capacity_carrier.inout][unit.capacity_carrier.carrier]
    if any(norm .== 0)
        @critical "Using a zero (0.0) efficiency in `conversion` is not allowed" unit = unit.name
    end

    for dir in [:in, :out]
        for (carrier, val) in unit.conversion_dict[dir]
            unit.conversion_dict[dir][carrier] = val ./ norm
        end
    end

    # Normalize min_conversion expression.
    if !isnothing(unit.conversion_at_min)
        norm = unit.conversion_at_min_dict[unit.capacity_carrier.inout][unit.capacity_carrier.carrier]
        if any(norm .== 0)
            @critical "Using a zero (0.0) efficiency in `conversion_at_min` is not allowed" unit = unit.name
        end

        for dir in [:in, :out]
            for (carrier, val) in unit.conversion_at_min_dict[dir]
                unit.conversion_at_min_dict[dir][carrier] = val ./ norm

                if any(
                    unit.conversion_dict[dir][carrier] .≈
                    unit.min_conversion .* unit.conversion_at_min_dict[dir][carrier],
                )
                    @warn "Linearization of efficiencies resulting in unexpected behaviour" unit = unit.name dir = dir carrier =
                        carrier.name
                end
            end
        end
    end

    return nothing
end

function _unit_capacity_limits(unit::Unit)
    # TODO: Refactor this to return a proper Expression.

    # TODO: "online conversion" is often immediately converted to an AffExpr, but could stay a VariableRef, fix this!

    # Get correct maximum.
    if !_isempty(unit.availability_factor)
        max_conversion = min.(1.0, access(unit.availability_factor, NonEmptyNumericalExpressionValue))
    elseif !_isempty(unit.availability)
        if !_isfixed(unit.capacity)
            @critical "Endogenuous <capacity> and <availability> are currently not supported" unit = unit.name
        end
        max_conversion =
            min.(
                1.0,
                access(unit.availability, NonEmptyNumericalExpressionValue) ./
                access(unit.capacity, NonEmptyNumericalExpressionValue),
            )
    else
        max_conversion = 1.0
    end

    # Calculate max / online conversion based on unit commitment.
    if unit.unit_commitment === :off
        max_conversion = max_conversion .* access(unit.unit_count, Float64)
        online_conversion = max_conversion
    else
        online_conversion = max_conversion .* unit.var.ison     # var_ison already includes unit.unit_count
        max_conversion = max_conversion .* access(unit.unit_count, Float64)
    end

    if isnothing(unit.min_conversion)
        # We are not limiting the min conversion.
        return Dict{Symbol, Union{NonEmptyNumericalExpressionValue, JuMP.AffExpr, Vector{JuMP.AffExpr}}}(
            :min => 0.0,
            :online => online_conversion::Union{NonEmptyNumericalExpressionValue, JuMP.AffExpr, Vector{JuMP.AffExpr}},
            :max => max_conversion::NonEmptyNumericalExpressionValue,
        )
    end

    return Dict{Symbol, Union{NonEmptyNumericalExpressionValue, JuMP.AffExpr, Vector{JuMP.AffExpr}}}(
        :min => (
            unit.min_conversion .* (unit.adapt_min_to_availability ? online_conversion : unit.var.ison)
        )::Union{NonEmptyNumericalExpressionValue, JuMP.AffExpr, Vector{JuMP.AffExpr}},
        :online => online_conversion::Union{NonEmptyNumericalExpressionValue, JuMP.AffExpr, Vector{JuMP.AffExpr}},
        :max => max_conversion::NonEmptyNumericalExpressionValue,
    )
end

# todo: Why is `total` being indexed using carrier names (strings)?
get_total(unit::Unit, direction::String, carrier::String) = _total(unit, Symbol(direction), carrier)
