"""
A `Profile` allows representing "model boundaries" - parts of initial problem that are not endogenously modelled - with
a support for time series data. Examples are hydro reservoir inflows, electricity demand, importing gas, and so on.
Besides modelling fixed profiles, they also allow different ways to modify the value endogenously.
"""
@kwdef struct Profile <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    init_state::Ref{Symbol} = Ref(:empty)
    constraint_safety::Bool
    constraint_safety_cost::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String
    raw"""```{"mandatory": "yes", "values": "string", "default": "-"}```
    `Carrier` of this `Profile`.
    """
    carrier::Carrier

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    value::_OptionalExpression = nothing
    node_from::Union{_String, Nothing} = nothing
    node_to::Union{_String, Nothing} = nothing

    mode::Symbol = :fixed
    lb::_OptionalExpression = nothing
    ub::_OptionalExpression = nothing
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
