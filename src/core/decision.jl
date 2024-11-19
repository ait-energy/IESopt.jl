"""
A `Decision` represents a basic decision variable in the model that can be used as input for various other core
component's settings, as well as have associated costs.
"""
@kwdef struct Decision <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    soft_constraints::Bool
    soft_constraints_penalty::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`0`"}```
    Minimum size of the decision value (considered for each "unit" if count allows multiple "units").
    """
    lb::_OptionalScalarInput = 0

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "``+\\infty``"}```
    Maximum size of the decision value (considered for each "unit" if count allows multiple "units").
    """
    ub::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "monetary (per value)", "default": "`0`"}```
    Cost that the decision value induces, given as ``cost \cdot value``.
    """
    cost::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "-"}```
    If `mode: fixed`, this value is used as the fixed value of the decision. This can be useful if this `Decision` was
    used in a previous optimization and its value should be fixed to that value in the next optimization (applying it
    where ever it is used, instead of needing to find all usages). Furthermore, this allows extracting the dual value of
    the constraint that fixes the value, assisting in approaches like Benders decomposition. Note that this does not
    change the induced cost in any way.
    """
    fixed_value::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "-", "unit": "monetary", "default": "-"}```
    This setting activates a "fixed cost" component for this decision variable, which requires that the model's problem
    type allows for binary variables (e.g., `MILP`). This can be used to model fixed costs that are only incurred if the
    decision variable is active (e.g., a fixed cost for an investment that is only incurred if the investment is made).
    If the decision is `0`, no fixed costs have to be paid; however, if the decision is greater than `0`, the fixed cost
    is incurred. Note that after deciding to activate the decision, the overall value is still determined in the usual
    (continuous) way, incuring the (variable) `cost` as well. More complex cost functions can be modelled by switching
    to mode `sos1` or `sos2` and using the `sos` parameter.
    """
    fixed_cost::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "`linear`, `binary`, `integer`, `sos1`, `sos2`, `fixed`", "unit": "-", "default": "`linear`"}```
    Type of the decision variable that is constructed. `linear` results in a continuous decision, `integer` results in a
    integer variable, `binary` constrains it to be either `0` or `1`. `sos1` and `sos2` can be used to activate SOS1 or
    SOS2 mode (used for piecewise linear costs). See `fixed_value` if setting this to `fixed`.
    """
    mode::Symbol = :linear

    raw"""```{"mandatory": "no", "values": "list", "unit": "-", "default": "-"}```
    TODO (meanwhile, refer to the SOS or PiecewiseLinearCost example).
    """
    sos::Vector{Dict{String, Float64}} = Vector()

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`1000`"}```
    Priority for the build order of components. Components with higher build_priority are built before.
    This can be useful for addons, that connect multiple components and rely on specific components being initialized
    before others.
    """
    build_priority::_OptionalScalarInput = nothing

    # [Internal] =======================================================================================================
    # -

    # [External] =======================================================================================================
    # -

    # [Optimization Container] =========================================================================================
    _ccoc = _CoreComponentOptContainer()
end

_result_fields(::Decision) = (:name, :mode)

function _prepare!(decision::Decision)
    return true
end

function _isvalid(decision::Decision)
    model = decision.model

    if (decision.mode in [:binary, :integer, :sos1, :sos2]) && !_is_milp(model)
        @critical "Model config only allows LP but MILP is required" decision = decision.name mode = decision.mode
    end

    if !isnothing(decision.fixed_cost) && !_is_milp(model)
        @critical "Model config only allows LP but MILP is required for modelling fixed costs" decision = decision.name mode =
            decision.mode
    end

    if (decision.mode === :binary) && !isnothing(decision.ub) && decision.ub != 1.0
        @critical "Binary variables with `ub != 1` are not possible" decision = decision.name ub = decision.ub
    end

    if (decision.mode in [:sos1, :sos2]) && !isnothing(decision.cost)
        @critical "SOS1/SOS2 Decisions should not have a `cost` parameter" decision = decision.name mode = decision.mode
    end

    if (decision.mode != :fixed) && !isnothing(decision.fixed_value)
        @critical "Decisions that are not fixed can not have a pre-set value" decision = decision.name
    end

    if !isnothing(decision.fixed_cost) && isnothing(decision.ub) && !(decision.mode in [:sos1, :sos2])
        @critical "Decisions with fixed costs require a defined upper bound" decision = decision.name
    end

    return true
end

function _result(decision::Decision, mode::String, field::String; result::Int=1)
    if !(field in ["value", "size", "count"])
        @error "Decision cannot extract field" decision = decision.name field = field
        return nothing
    end

    if mode == "dual"
        if decision.mode != :fixed
            @error "Extracting <dual> of non-fixed Decisions is currently not supported" decision = decision.name
            return nothing
        else
            # todo: JuMP dual result fix
            if result != 1
                @error "Duals are currently only available for the first result (this is a limitation of the JuMP interface)"
            end
            return "Decision.fixed_value.dual", JuMP.reduced_cost(decision.var.value)
        end
    end

    if mode != "value"
        @error "Decision cannot apply mode to extraction of field" decision = decision.name mode = mode
        return nothing
    end

    if field in ["size", "count"]
        @error "`decision:size` and `decision:count` are deprecated and most likely do not work as expected; please change to extracting `decision:value`" decision =
            decision.name mode = mode
    end

    if field == "value"
        return "Decision.value", JuMP.value.(_value(decision); result=result)
    elseif field == "size"
        return "Decision.size", JuMP.value.(_size(decision); result=result)
    elseif field == "count"
        return "Decision.count", JuMP.value.(_count(decision); result=result)
    end

    @error "Unknown result extraction" decision = decision.name mode = mode field = field
    return nothing
end

_build_priority(decision::Decision) = _build_priority(decision.build_priority, 1000.0)

include("decision/con_fixed.jl")
include("decision/con_sos_value.jl")
include("decision/con_sos1.jl")
include("decision/con_sos2.jl")
include("decision/obj_fixed.jl")
include("decision/obj_sos.jl")
include("decision/obj_value.jl")
include("decision/var_fixed.jl")
include("decision/var_sos.jl")
include("decision/var_value.jl")

function _construct_variables!(decision::Decision)
    _decision_var_fixed!(decision)
    _decision_var_sos!(decision)
    _decision_var_value!(decision)
    return nothing
end

function _construct_constraints!(decision::Decision)
    _decision_con_fixed!(decision)
    _decision_con_sos_value!(decision)
    _decision_con_sos1!(decision)
    return _decision_con_sos2!(decision)
end

function _construct_objective!(decision::Decision)
    _decision_obj_fixed!(decision)
    _decision_obj_sos!(decision)
    _decision_obj_value!(decision)
    return nothing
end

_value(decision::Decision) = decision.var.value
_count(decision::Decision) = decision.var.value
_size(decision::Decision) = decision.var.value

_value(decision::Decision, t::_ID) = _value(decision)
_count(decision::Decision, t::_ID) = _count(decision)
_size(decision::Decision, t::_ID) = _size(decision)
