"""
A `Node` represents a basic intersection/hub for energy flows. This can for example be some sort of bus (for electrical
systems). It enforces a nodal balance equation (= "energy that flows into it must flow out") for every
[`Snapshot`](@ref). Enabling the internal state of the `Node` allows it to act as energy storage, modifying the nodal
balance equation. This allows using `Node`s for various storage tasks (like batteries, hydro reservoirs, heat storages,
...). 

!!! details "Basic Examples"
    A `Node` that represents an electrical bus:
    ```yaml
    bus:
      type: Node
      carrier: electricity
    ```
    A `Node` that represents a simplified hydrogen storage:
    ```yaml
    store:
      type: Node
      carrier: hydrogen
      has_state: true
      state_lb: 0
      state_ub: 50
    ```
"""
@kwdef struct Node <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    soft_constraints::Bool
    soft_constraints_penalty::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String
    raw"""```{"mandatory": "yes", "values": "string", "unit": "-", "default": "-"}```
    `Carrier` of this `Node`. All connecting components need to respect that.
    """
    carrier::Carrier

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    raw"""```{"mandatory": "no", "values": "`true`, `false`", "unit": "-", "default": "`false`"}```
    If `true`, the `Node` is considered to have an internal state ("stateful `Node`"). This allows it to act as energy
    storage. Connect `Connection`s or `Unit`s to it, acting as charger/discharger.
    """
    has_state::Bool = false

    raw"""```{"mandatory": "no", "values": "numeric, `col@file`, `decision:value`", "unit": "energy", "default": "``-\\infty``"}```
    Lower bound of the internal state, requires `has_state = true`.
    """
    state_lb::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "numeric, `col@file`, `decision:value`", "unit": "energy", "default": "``+\\infty``"}```
    Upper bound of the internal state, requires `has_state = true`.
    """
    state_ub::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "`eq`, `geq`, or `disabled`", "unit": "-", "default": "`eq`"}```
    Controls how the state considers the boundary between last and first `Snapshot`. `disabled` disables cyclic
    behaviour of the state (see also `state_initial`), `eq` leads to the state at the end of the year being the initial
    state at the beginning of the year, while `geq` does the same while allowing the end-of-year state to be higher (=
    "allowing to destroy energy at the end of the year").
    """
    state_cyclic::Symbol = :eq

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "energy", "default": "-"}```
    Sets the initial state. Must be used in combination with `state_cyclic = disabled`.
    """
    state_initial::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "energy", "default": "-"}```
    Sets the final state. Must be used in combination with `state_cyclic = disabled`.
    """
    state_final::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "``\\in [0, 1]``", "unit": "-", "default": "0"}```
    Per hour percentage loss of state (losing 1% should be set as `0.01`), will be scaled automatically for
    `Snapshot`s that are not one hour long.
    """
    state_percentage_loss::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "`enforce`, `destroy`, or `create`", "unit": "-", "default": "`enforce`"}```
    Can only be used for `has_state = false`. `enforce` forces total injections to always be zero (similar to
    Kirchhoff's current law), `create` allows "supply < demand", `destroy` allows "supply > demand", at this `Node`.
    """
    nodal_balance::Symbol = :enforce

    raw"""```{"mandatory": "no", "values": "integer", "unit": "-", "default": "-"}```
    TODO.
    """
    sum_window_size::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "integer", "unit": "-", "default": "`1`"}```
    TODO.
    """
    sum_window_step::_ScalarInput = 1

    etdf_group::Union{_String, Nothing} = nothing   # todo: retire this in favor of pf_zone

    # Powerflow
    pf_slack::Bool = false

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`0`"}```
    Priority for the build order of components. Components with higher build_priority are built before.
    This can be useful for addons, that connect multiple components and rely on specific components being initialized
    before others.
    """
    build_priority::_OptionalScalarInput = nothing

    # [Internal] =======================================================================================================
    # -

    # [External] =======================================================================================================
    # results::Union{Dict, Nothing} = nothing

    # [Optimization Container] =========================================================================================
    _ccoc = _CoreComponentOptContainer()
end

_result_fields(::Node) = (:name, :carrier, :has_state, :nodal_balance)

function _prepare!(node::Node)
    return true
end

function _isvalid(node::Node)
    (node.state_cyclic in [:eq, :geq, :disabled]) || (@critical "<state_cyclic> invalid" node = node.name)

    if !isnothing(node.etdf_group) && node.has_state
        @critical "Activating ETDF is not supported for stateful nodes" node = node.name
    end

    if (node.nodal_balance === :sum) && _has_representative_snapshots(node.model)
        @critical "Sum Nodes are not possible with representative Snapshots" node = node.name
    end

    if node.nodal_balance === :sum
        if node.sum_window_size == length(get_T(node.model))
            if node.sum_window_step != 1
                @error "`sum_window_step` should probably be 1" node = node.name
            end
        end
        if isnothing(node.sum_window_step)
            @critical "`sum_window_step` undefined" node = node.name
        end
    end

    return true
end

function _setup!(node::Node)
    model = node.model

    node.con.nodalbalance = Vector{JuMP.ConstraintRef}(undef, get_T(model)[end])

    if !isnothing(node.etdf_group)
        # Check if we need to create the current ETDF group.
        if !haskey(internal(model).aux.etdf.groups, node.etdf_group)
            internal(model).aux.etdf.groups[node.etdf_group] = []
        end
    end

    return nothing
end

function _result(node::Node, mode::String, field::String; result::Int=1)
    if !(field in ["state", "nodal_balance", "injection", "extraction"])
        @error "Node cannot extract field" node = node.name field = field
        return nothing
    end

    if mode == "dual" && field == "nodal_balance"
        # todo: JuMP dual result fix
        if result != 1
            @error "Duals are currently only available for the first result (this is a limitation of the JuMP interface)"
        end
        return "$(node.name).nodal_balance.shadow_price", JuMP.shadow_price.(node.con.nodalbalance)
    end

    if mode == "value" && field == "state"
        return "$(node.name).state", JuMP.value.(node.var.state; result=result)
    end

    if field == "injection"
        if mode == "value"
            return "$(node.name).injection", JuMP.value.(node.exp.injection; result=result)
        elseif mode == "sum"
            return "$(node.name).injection", sum(JuMP.value.(node.exp.injection; result=result))
        end
    elseif field == "extraction"
        if mode == "value"
            return "$(node.name).extraction", -JuMP.value.(node.exp.injection; result=result)
        elseif mode == "sum"
            return "$(node.name).extraction", -sum(JuMP.value.(node.exp.injection; result=result))
        end
    end

    @error "Unknown result extraction" node = node.name mode = mode field = field
    return nothing
end

include("node/exp_injection.jl")
include("node/var_state.jl")
include("node/var_pf_theta.jl")
include("node/con_state_bounds.jl")
include("node/con_nodalbalance.jl")
include("node/con_first_state.jl")
include("node/con_last_state.jl")

function _construct_expressions!(node::Node)
    _node_exp_injection!(node)
    return nothing
end

function _construct_variables!(node::Node)
    _node_var_state!(node)
    _node_var_pf_theta!(node)
    return nothing
end

function _after_construct_variables!(node::Node)
    # We can now properly finalize the `state_lb`, and `state_ub`.
    _finalize(node.state_lb)
    _finalize(node.state_ub)
    _finalize(node.state_initial)
    _finalize(node.state_final)
    # Check expressions
    if node.state_initial.value isa Vector
        @critical "[build] The initial value of a Node must be scalar." component = node.name
    end
    if node.state_final isa Vector
        @critical "[build] The final value of a Node must be scalar." component = node.name
    end

    return nothing
end

function _construct_constraints!(node::Node)
    _node_con_state_bounds!(node)
    _node_con_nodalbalance!(node) # 25% here
    _node_con_first_state!(node)
    _node_con_last_state!(node)
    return nothing
end

function _construct_objective!(node::Node)
    return nothing
end
