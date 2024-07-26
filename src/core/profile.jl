"""
A `Profile` allows representing "model boundaries" - parts of initial problem that are not endogenously modelled - with
a support for time series data. Examples are hydro reservoir inflows, electricity demand, importing gas, and so on.
Besides modelling fixed profiles, they also allow different ways to modify the value endogenously.

!!! details "Basic Examples"
    A `Profile` that depicts a fixed electricity demand:
    ```yaml
    demand_XY:
      type: Profile
      carrier: electricity
      node_from: grid
      value: demand_XY@input_file
    ```
    A `Profile` that handles cost of fuel:
    ```yaml
    fuel_gas:
      type: Profile
      carrier: gas
      node_to: country_gas_grid
      mode: create
      cost: 100.0
    ```
    A `Profile` that handles CO2 emission costs:
    ```yaml
    co2_cost:
      type: Profile
      carrier: co2
      node_from: total_co2
      mode: destroy
      cost: 150.0
    ```
    A `Profile` that handles selling electricity:
    ```yaml
    sell_electricity:
      type: Profile
      carrier: electricity
      node_from: internal_grid_node
      mode: destroy
      cost: -30.0
    ```
"""
@kwdef struct Profile <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    init_state::Ref{Symbol} = Ref(:empty)
    constraint_safety::Bool
    constraint_safety_cost::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String

    raw"""```{"mandatory": "yes", "values": "string", "unit": "-", "default": "-"}```
    `Carrier` of this `Profile`. Must match the `Carrier` of the `Node` that this connects to.
    """
    carrier::Carrier

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    raw"""```{"mandatory": "no", "values": "numeric, `col@file`", "unit": "power", "default": "-"}```
    The concrete value of this `Profile` - either static or as time series. Only applicable if `mode: fixed`.
    """
    value::_OptionalExpression = nothing

    raw"""```{"mandatory": "no", "values": "string", "unit": "-", "default": "-"}```
    Name of the `Node` that this `Profile` draws energy from. Exactly one of `node_from` and `node_to` must be set.
    """
    node_from::Union{_String, Nothing} = nothing

    raw"""```{"mandatory": "no", "values": "string", "unit": "-", "default": "-"}```
    Name of the `Node` that this `Profile` feeds energy to. Exactly one of `node_from` and `node_to` must be set.
    """
    node_to::Union{_String, Nothing} = nothing

    raw"""```{"mandatory": "no", "values": "-", "unit": "-", "default": "`fixed`"}```
    The mode of operation of this `Profile`. `fixed` uses the supplied `value`, `ranged` allows ranging between `lb` and
    `ub`, while `create` (must specify `node_to`) and `destroy` (must specify `node_from`) handle arbitrary energy flows
    that are bounded from below by `0`. Use `fixed` if you want to fix the value of the `Profile` to a specific value,
    e.g., a given energy demand. Use `create` to "import" energy into the model, e.g., from a not explicitly modelled
    gas market, indcucing a certain `cost` for buying that energy. Use `destroy` to "export" energy from the model,
    e.g., to handle CO2 going into the atmosphere (which may be taxed, etc., by the `cost` of this `Profile`). Use
    `ranged` if you need more fine grained control over the value of the `Profile`, than what `create` and `destroy`
    allow (e.g., a grid limited energy supplier).
    """
    mode::Symbol = :fixed

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "power", "default": "``-\\infty``"}```
    The lower bound of the range of this `Profile` (must be used together with `mode: ranged`).
    """
    lb::_OptionalExpression = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "power", "default": "``+\\infty``"}```
    The upper bound of the range of this `Profile` (must be used together with `mode: ranged`).
    """
    ub::_OptionalExpression = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "monetary per energy", "default": "`0`"}```
    Cost per unit of energy that this `Profile` injects or withdraws from a `Node`. Refer to the basic examples to see
    how this can be combined with `mode` for different use cases.
    """
    cost::_OptionalExpression = nothing

    allow_deviation::Symbol = :off
    cost_deviation::_OptionalScalarInput = nothing

    # [Internal] =======================================================================================================
    # -

    # [External] =======================================================================================================
    # results::Union{Dict, Nothing} = nothing

    # [Optimization Container] =========================================================================================
    _ccoc = _CoreComponentOptContainer()
end

_result_fields(::Profile) = (:name, :carrier, :node_from, :node_to, :mode)

function _prepare!(profile::Profile)
    model = profile.model

    # Extract the carrier from the connected nodes.
    if !isnothing(profile.node_from) && (profile.carrier != component(model, profile.node_from).carrier)
        @critical "Profile <carrier> mismatch" profile = profile.name node_from = profile.node_from
    end
    if !isnothing(profile.node_to) && (profile.carrier != component(model, profile.node_to).carrier)
        @critical "Profile <carrier> mismatch" profile = profile.name node_to = profile.node_to
    end

    return true
end

function _isvalid(profile::Profile)
    if isnothing(profile.carrier)
        @critical "<carrier> could not be detected correctly" profile = profile.name
    end

    if (profile.mode === :create) || (profile.mode === :destroy)
        !isnothing(profile.lb) && (@warn "Setting <lb> is ignored" profile = profile.name mode = profile.mode)
        !isnothing(profile.ub) && (@warn "Setting <ub> is ignored" profile = profile.name mode = profile.mode)
    end

    if !(profile.mode in [:fixed, :create, :destroy, :ranged])
        @critical "Invalid <mode>" profile = profile.name
    end

    if !isnothing(profile.value) && (profile.mode != :fixed)
        @critical "Setting <value> of Profile may result in unexpected behaviour, because <mode> is not `fixed`" profile =
            profile.name mode = profile.mode
    end

    if !isnothing(profile.cost_deviation) || (profile.allow_deviation != :off)
        @error "Profile deviations are deprecated" profile = profile.name
    end

    return true
end

function _setup!(profile::Profile)
    return nothing
end

function _result(profile::Profile, mode::String, field::String; result::Int=1)
    if field != "value"
        @error "Profile cannot extract field" profile = profile.name field = field
        return nothing
    end

    if mode == "dual"
        @error "Extracting <dual> of Profile is currently not supported" profile = profile.name
        return nothing
    end

    value = JuMP.value.(profile.exp.value; result=result)

    if mode == "value"
        return "$(profile.name).value", value
    elseif mode == "sum"
        return "Profile.sum.value", sum(value)
    end

    @error "Unknown result extraction" profile = profile.name mode = mode field = field
    return nothing
end

include("profile/exp_value.jl")
include("profile/var_aux_value.jl")
include("profile/con_value_bounds.jl")
include("profile/obj_cost.jl")

function _construct_expressions!(profile::Profile)
    @profile profile.model _profile_exp_value!(profile)
    return nothing
end

function _construct_variables!(profile::Profile)
    @profile profile.model _profile_var_aux_value!(profile)
    return nothing
end

function _after_construct_variables!(profile::Profile)
    model = profile.model
    components = _iesopt(model).model.components

    if !isnothing(profile.value)
        if (profile.mode === :fixed) && _iesopt_config(model).parametric
            # Create all representatives.
            _repr = Dict(
                t => @variable(model, base_name = _base_name(profile, "aux_value[$(t)]")) for
                t in _iesopt(model).model.T if _iesopt(model).model.snapshots[t].is_representative
            )
            # Create all variables, either as themselves or their representative.
            profile.var.aux_value = collect(
                _iesopt(model).model.snapshots[t].is_representative ? _repr[t] :
                _repr[_iesopt(model).model.snapshots[t].representative] for t in _iesopt(model).model.T
            )
        end

        # After all variables are constructed the `value` can be finalized and used.
        _finalize(profile.value)
        for t in _iesopt(model).model.T
            _repr_t =
                _iesopt(model).model.snapshots[t].is_representative ? t :
                _iesopt(model).model.snapshots[t].representative
            val = _get(profile.value, _repr_t)

            if (profile.mode === :fixed) && _iesopt_config(model).parametric
                JuMP.fix(profile.var.aux_value[t], val; force=true)
                JuMP.add_to_expression!(profile.exp.value[t], profile.var.aux_value[t])
            else
                JuMP.add_to_expression!(profile.exp.value[t], val)
            end
        end
    end

    # Now we can be sure that the expression is properly setup, add it to the respective Nodes.
    if profile.node_from !== nothing
        JuMP.add_to_expression!.(components[profile.node_from].exp.injection, profile.exp.value, -1.0)
    end
    if profile.node_to !== nothing
        JuMP.add_to_expression!.(components[profile.node_to].exp.injection, profile.exp.value)
    end

    # We can now also properly finalize the `lb`, `ub`, and `cost`.
    !isnothing(profile.lb) && _finalize(profile.lb)
    !isnothing(profile.ub) && _finalize(profile.ub)
    !isnothing(profile.cost) && _finalize(profile.cost)

    return nothing
end

function _construct_constraints!(profile::Profile)
    @profile profile.model _profile_con_value_bounds!(profile)
    return nothing
end

function _construct_objective!(profile::Profile)
    @profile profile.model _profile_obj_cost!(profile)

    return nothing
end
