"""
A `Unit` allows transforming one (or many) forms of energy into another one (or many), given some constraints and costs.
"""
@kwdef struct Unit <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    init_state::Ref{Symbol} = Ref(:empty)
    constraint_safety::Bool
    constraint_safety_cost::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String

    raw"""```{"mandatory": "yes", "values": "string", "default": "-"}```
    The conversion expression describing how this `Unit` transforms energy. Specified in the form of "$\alpha \cdot
    carrier_1 + \beta \cdot carrier_2$ -> $\gamma \cdot carrier_3 + \delta \cdot carrier_4$". Coefficients allow simple
    numerical calculations, but are not allowed to include spaces (so e.g. `(1.0/9.0)` is valid). Coefficients are
    allowed to be `NumericalInput`s, resulting in `column@data_file` being a valid coefficient (this can be used e.g.
    for time-varying COPs of heatpumps).
    """
    conversion::_String

    raw"""```{"mandatory": "yes", "values": "string", "default": "-"}```
    Maximum capacity of this `Unit`, to be given in the format `X in/out:carrier` where `X` is the amount, `in` or `out`
    (followed by `:`) specifies whether the limit is to be placed on the in- our output of this `Unit`, and `carrier`
    specifies the respective `Carrier`. Example: `100 in:electricity` (to limit the "input rating").
    """
    capacity::_Expression

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    inputs::Dict{Carrier, String} = Dict()
    outputs::Dict{Carrier, String} = Dict()

    availability::_OptionalExpression = nothing
    availability_factor::_OptionalExpression = nothing
    adapt_min_to_availability::Bool = false

    marginal_cost::_OptionalExpression = nothing

    enable_ramp_up::Bool = false
    enable_ramp_down::Bool = false
    ramp_up_cost::_OptionalScalarInput = nothing
    ramp_down_cost::_OptionalScalarInput = nothing
    ramp_up_limit::_OptionalScalarInput = nothing
    ramp_down_limit::_OptionalScalarInput = nothing

    min_on_time::_OptionalScalarInput = nothing
    min_off_time::_OptionalScalarInput = nothing
    on_time_before::_ScalarInput = 0
    off_time_before::_ScalarInput = 0
    is_on_before::_Bound = 1        # todo: why is this a bound (and not _OptionalScalarInput)

    unit_commitment::Symbol = :off
    unit_count::_OptionalExpression  # default=1 is enforced in `parser.jl`
    min_conversion::_OptionalScalarInput = nothing
    conversion_at_min::_OptionalString = nothing
    startup_cost::_OptionalScalarInput = nothing

    # [Internal] =======================================================================================================
    conversion_dict::Dict{Symbol, Dict{Carrier, _NumericalInput}} = Dict(:in => Dict(), :out => Dict())
    conversion_at_min_dict::Dict{Symbol, Dict{Carrier, _NumericalInput}} = Dict(:in => Dict(), :out => Dict())

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
        _vec = Vector{JuMP.AffExpr}(undef, _iesopt(model).model.T[end])
        for i in eachindex(_vec)
            _vec[i] = JuMP.AffExpr(0.0)
        end
        unit.exp[Symbol("in_$(carrier.name)")] = _vec
    end
    for carrier in keys(unit.outputs)
        _vec = Vector{JuMP.AffExpr}(undef, _iesopt(model).model.T[end])
        for i in eachindex(_vec)
            _vec[i] = JuMP.AffExpr(0.0)
        end
        unit.exp[Symbol("out_$(carrier.name)")] = _vec
    end

    # Convert string formula to proper conversion dictionary.
    @profile unit.model _convert_unit_conversion_dict!(carriers, unit)      # todo: stop passing carriers, as soon as there is unit._model

    # Normalize the conversion expressions to allow correct handling later on.
    @profile unit.model _normalize_conversion_expressions!(unit)

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

    if (unit.enable_ramp_up || unit.enable_ramp_down) && (_get(unit.unit_count) != 1)
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
    if (_get(unit.unit_count) != 1) && (!isnothing(unit.min_on_time) || !isnothing(unit.min_off_time))
        @critical "min_on_time/min_off_time is currently not supported for Units with `unit.count > 1`" unit = unit.name
    end

    # todo: resolve the issue and then remove this
    if (
        (!isnothing(unit.min_on_time) || !isnothing(unit.min_off_time)) &&
        any(_weight(model, t) != 1 for t in _iesopt(model).model.T[2:end])
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
                ) for t in _iesopt(unit.model).model.T
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
    !isnothing(unit.availability) && _finalize(unit.availability)
    !isnothing(unit.availability_factor) && _finalize(unit.availability_factor)
    !isnothing(unit.unit_count) && _finalize(unit.unit_count)
    !isnothing(unit.capacity) && _finalize(unit.capacity)
    !isnothing(unit.marginal_cost) && _finalize(unit.marginal_cost)

    # `var_ison` needs to be constructed before `var_conversion`
    @profile unit.model _unit_var_ison!(unit)

    @profile unit.model _unit_var_conversion!(unit)
    @profile unit.model _unit_var_ramp!(unit)
    @profile unit.model _unit_var_startup!(unit)

    return nothing
end

function _construct_constraints!(unit::Unit)
    @profile unit.model _unit_con_conversion_bounds!(unit)
    @profile unit.model _unit_con_ison!(unit)
    @profile unit.model _unit_con_min_onoff_time!(unit)
    @profile unit.model _unit_con_startup!(unit)
    @profile unit.model _unit_con_ramp!(unit)
    @profile unit.model _unit_con_ramp_limit!(unit)

    return nothing
end

function _construct_objective!(unit::Unit)
    @profile unit.model _unit_obj_marginal_cost!(unit)
    @profile unit.model _unit_obj_startup_cost!(unit)
    @profile unit.model _unit_obj_ramp_cost!(unit)

    return nothing
end

function _convert_unit_conversion_dict!(carriers::Dict{String, Carrier}, unit::Unit)
    # Convert the mandatory conversion.
    lhs, rhs = split(unit.conversion, "->")
    lhs = split(lhs, "+")
    rhs = split(rhs, "+")
    for item in lhs
        item = strip(item)
        item == "~" && continue
        mult, carrier_str = split(item, " ")
        if !isnothing(findfirst('@', mult))
            unit.conversion_dict[:in][carriers[carrier_str]] = _conv_S2NI(unit.model, mult) # todo ????
        else
            unit.conversion_dict[:in][carriers[carrier_str]] = _conv_S2NI(unit.model, mult) # todo ????
        end
    end
    for item in rhs
        item = strip(item)
        item == "~" && continue
        mult, carrier_str = split(item, " ")
        if !isnothing(findfirst('@', mult))
            unit.conversion_dict[:out][carriers[carrier_str]] = _conv_S2NI(unit.model, mult) # todo ????
        else
            unit.conversion_dict[:out][carriers[carrier_str]] = _conv_S2NI(unit.model, mult) # todo ????
        end
    end

    isnothing(unit.conversion_at_min) && return

    # Convert the optional "minconversion" conversion.
    lhs, rhs = split(unit.conversion_at_min, "->")
    lhs = split(lhs, "+")
    rhs = split(rhs, "+")
    for item in lhs
        item = strip(item)
        item == "~" && continue
        mult, carrier_str = split(item, " ")
        unit.conversion_at_min_dict[:in][carriers[carrier_str]] = _conv_S2NI(unit.model, mult)
    end
    for item in rhs
        item = strip(item)
        item == "~" && continue
        mult, carrier_str = split(item, " ")
        unit.conversion_at_min_dict[:out][carriers[carrier_str]] = _conv_S2NI(unit.model, mult)
    end

    return nothing
end

function _normalize_conversion_expressions!(unit::Unit)
    # Normalize default conversion expression.
    norm = unit.conversion_dict[unit.capacity_carrier.inout][unit.capacity_carrier.carrier]
    for dir in [:in, :out]
        for (carrier, val) in unit.conversion_dict[dir]
            unit.conversion_dict[dir][carrier] = val ./ norm
        end
    end

    # Normalize min_conversion expression.
    if !isnothing(unit.conversion_at_min)
        norm = unit.conversion_at_min_dict[unit.capacity_carrier.inout][unit.capacity_carrier.carrier]
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
    # Get correct maximum.
    if !isnothing(unit.availability_factor)
        max_conversion = min.(1.0, _get(unit.availability_factor))
    elseif !isnothing(unit.availability)
        if !isnothing(unit.capacity.decisions) && length(unit.capacity.decisions) > 0
            @critical "Endogenuous <capacity> and <availability> are currently not supported" unit = unit.name
        end
        max_conversion = min.(1.0, _get(unit.availability) ./ _get(unit.capacity))
    else
        max_conversion = 1.0
    end

    # Calculate max / online conversion based on unit commitment.
    if unit.unit_commitment === :off
        max_conversion = max_conversion .* _get(unit.unit_count)
        online_conversion = max_conversion
    else
        online_conversion = max_conversion .* unit.var.ison     # var_ison already includes unit.unit_count
        max_conversion = max_conversion .* _get(unit.unit_count)
    end

    if isnothing(unit.min_conversion)
        # We are not limiting the min conversion.
        return Dict{Symbol, Any}(:min => 0.0, :online => online_conversion, :max => max_conversion)
    end

    return Dict{Symbol, Any}(
        :min => unit.min_conversion .* (unit.adapt_min_to_availability ? online_conversion : unit.var.ison),
        :online => online_conversion,
        :max => max_conversion,
    )
end

# todo: Why is `total` being indexed using carrier names (strings)?
get_total(unit::Unit, direction::String, carrier::String) = _total(unit, Symbol(direction), carrier)
