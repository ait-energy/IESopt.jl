"""
A `Connection` is used to model arbitrary flows of energy between `Node`s. It allows for limits, costs, delays, ...
"""
@kwdef struct Connection <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model
    constraint_safety::Bool
    constraint_safety_cost::_ScalarInput

    # [Mandatory] ======================================================================================================
    name::_String

    raw"""```{"mandatory": "yes", "values": "string", "unit": "-", "default": "-"}```
    This `Connection` models a flow from `node_from` to `node_to` (both are `Node`s).
    """
    node_from::Union{_String, Nothing} = nothing

    raw"""```{"mandatory": "yes", "values": "string", "unit": "-", "default": "-"}```
    This `Connection` models a flow from `node_from` to `node_to` (both are `Node`s).
    """
    node_to::Union{_String, Nothing} = nothing

    # [Optional] =======================================================================================================
    config::Dict{String, Any} = Dict()
    ext::Dict{String, Any} = Dict()
    addon::Union{String, Nothing} = nothing
    conditional::Bool = false

    raw"""```{"mandatory": "no", "values": "string", "unit": "-", "default": "-"}```
    `Carrier` of this `Connection`. If not given, automatically picks the `carrier` of the `Node`s it connects. This
    parameter is not necessary, and only exists to allow for a more explicit definition.
    """
    carrier::Carrier

    raw"""```{"mandatory": "no", "values": "numeric, `col@file`, `decision:value`", "unit": "power", "default": "``+\\infty``"}```
    The symmetric bound on this `Connection`'s flow. Results in `lb = -capacity` and `ub = capacity`. Must not be
    specified if `lb`, `ub`, or both are explicitly stated.
    """
    capacity::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "numeric, `col@file`, `decision:value`", "unit": "power", "default": "``-\\infty``"}```
    Lower bound of this `Connection`'s flow.
    """
    lb::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "numeric, `col@file`, `decision:value`", "unit": "power", "default": "``+\\infty``"}```
    Upper bound of this `Connection`'s flow.
    """
    ub::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "monetary (per energy)", "default": "-"}```
    Cost of every unit of energy flow over this connection that is added to the model's objective function. Keep in mind
    that negative flows will induce negative costs, which can be used to model revenues. Further, a bidirectional
    `Connection` (if `lb < 0`, which is the default, or if `capacity` is used) with a positive `cost` will lead to
    negative costs for the reverse flow. If you do not want this, split the `Connection` into two separate ones, each
    being unidirectional (with `lb: 0`). Remember, that these can share the same "capacity" (which is then set as`ub`),
    even when using `decision:value` or `col@file` as value.
    """
    cost::Expression = @_default_expression(nothing)

    raw"""```{"mandatory": "no", "values": "``\\in [0, 1]``", "unit": "-", "default": "0"}```
    Fractional loss when transfering energy. This loss occurs "at the destination", which means that for a loss of 5%,
    set as `loss: 0.05`, and considering a `Snapshot` where the `Connection` has a flow value of `100`, it will
    "extract" `100` from `node_from` and "inject" `95` into `node_to`. Since the flow variable is given as power, this
    would, e.g., translate to consuming 200 units of energy at `node_from` and injecting 190 units at `node_to`, if the
    `Snapshot` duration is 2 hours.
    """
    loss::Expression = @_default_expression(0.0)

    # Energy Transfer Distribution Factors
    etdf::Union{Dict{<:Union{_ID, _String}, <:Any}, _String, Nothing} = nothing

    # Powerflow
    is_pf_controlled::Ref{Bool} = Ref(false)
    pf_I::_OptionalScalarInput = nothing
    pf_V::_OptionalScalarInput = nothing
    pf_X::_OptionalScalarInput = nothing
    pf_R::_OptionalScalarInput = nothing
    pf_B::_OptionalScalarInput = nothing

    raw"""```{"mandatory": "no", "values": "numeric", "unit": "-", "default": "`0`"}```
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

_result_fields(::Connection) = (:name, :carrier, :node_from, :node_to)

function _check(connection::Connection)
    !connection.conditional && return true

    # Check if the connected nodes exist.
    !haskey(_iesopt(connection.model).model.components, connection.node_from) && return false
    !haskey(_iesopt(connection.model).model.components, connection.node_to) && return false

    return true
end

function _prepare!(connection::Connection)
    model = connection.model

    if !isnothing(connection.etdf)
        @error "ETDFs are disabled until a rework to PowerModels.jl is done" connection = connection.name
        # if isa(connection.etdf, _String)
        #     # Load ETDF from supplied file.
        #     data = _iesopt(model).input.files[connection.etdf]

        #     if hasproperty(data, "connection.name")
        #         # This is a static ETDF matrix (n x l).
        #         df = @view data[data[!, "connection.name"] .== connection.name, 2:end]
        #         connection.etdf = Dict(ids[k] => v for (k, v) in Pair.(names(df), collect(df[1, :])))
        #     else
        #         # This is a dynamic ETDF matrix (t x nl).
        #         connection.etdf = Dict{_ID, Vector{_ScalarInput}}()
        #         for col in names(data)
        #             node, conn = split(col, ":")
        #             conn != connection.name && continue
        #             connection.etdf[ids[node]] = data[!, col]
        #         end
        #     end
        # else
        #     # Convert string name of ETDFs to proper Node ids.
        #     connection.etdf = Dict(
        #         ids[k] =>
        #             connection.etdf[k] isa Number ? connection.etdf[k] : _conv_S2NI(model, connection.etdf[k]) for
        #         k in keys(connection.etdf)
        #     )
        # end
    end

    # Cutoff ETDFs based on model threshold.
    if !isnothing(connection.etdf)
        # for (node, val) in connection.etdf
        #     if isa(connection.etdf[node], Number)
        #         connection.etdf[node] =
        #             abs(connection.etdf[node]) < _iesopt_config(model).etdf_threshold ? 0 : connection.etdf[node]
        #     else
        #         for t in 1:length(connection.etdf[node])
        #             connection.etdf[node][t] =
        #                 abs(connection.etdf[node][t]) < _iesopt_config(model).etdf_threshold ? 0 :
        #                 connection.etdf[node][t]
        #         end
        #     end
        # end
    end

    # Check whether this Connection is controlled by a global PF addon
    connection.is_pf_controlled[] = any([
        !isnothing(connection.pf_B),
        !isnothing(connection.pf_I),
        !isnothing(connection.pf_R),
        !isnothing(connection.pf_V),
        !isnothing(connection.pf_X),
    ])

    if connection.is_pf_controlled[]
        # Do proper per-unit conversion for a three-phase system:
        # see: https://electricalacademia.com/electric-power/per-unit-calculation-per-unit-system-examples/
        V_base = connection.pf_V * 1e3      # voltage base, based on line voltage
        S_base = 1e6                        # apparent power base = 1 MVA
        I_base = S_base / (V_base * sqrt(3))
        Z_base = V_base / (I_base * sqrt(3))

        connection.pf_V = (connection.pf_V * 1e3) / V_base
        connection.pf_I = (connection.pf_I * 1e3) / I_base
        if !isnothing(connection.pf_R)
            connection.pf_R = connection.pf_R / Z_base
        end
        if !isnothing(connection.pf_X)
            connection.pf_X = connection.pf_X / Z_base
        end

        if _isempty(connection.capacity)
            # Only calculate capacity if it is not given by the user
            connection.capacity = _convert_to_expression(model, connection.pf_V * connection.pf_I)
        end
        # todo: convert B1
    end

    return true
end

function _isvalid(connection::Connection)
    if !_isempty(connection.capacity) && (!_isempty(connection.lb))
        @critical "Setting <capacity> as well as <lb> for Connection can result in unexpected behaviour" connection =
            connection.name
    end

    if !_isempty(connection.capacity) && (!_isempty(connection.ub))
        @critical "Setting <capacity> as well as <ub> for Connection can result in unexpected behaviour" connection =
            connection.name
    end

    if !_isfixed(connection.cost)
        @critical "Endogenuous Connection <cost> leads to quadratic expressions and is currently not supported" connection =
            connection.name
    end

    if !_isempty(connection.loss) &&
       (_isempty(connection.lb) || !_isfixed(connection.lb) || any(<(0), connection.lb.value))
        @critical "Setting <loss> for Connection requires nonnegative <lb>" connection = connection.name
    end

    return true
end

function _setup!(connection::Connection)
    return nothing
end

function _result(connection::Connection, mode::String, field::String; result::Int=1)
    if isnothing(findfirst("flow", field))
        @error "Connection cannot extract field" connection = connection.name field = field
        return nothing
    end

    if connection.is_pf_controlled[]
        if mode == "value" && field == "flow"
            return "$(connection.name).flow", JuMP.value.(connection.exp.pf_flow; result=result)
        elseif mode == "sum" && field == "flow"
            return "$(connection.name).sum.flow", sum(JuMP.value.(connection.exp.pf_flow; result=result))
        end
    elseif !isnothing(connection.etdf)
        @error "ETDF results are disabled until a rework to PowerModels.jl is done" connection = connection.name
        # flow = sum(
        #     _iesopt(connection.model).model.components[id].exp.injection .* connection.etdf[id] for
        #     id in keys(connection.etdf)
        # )
        # if mode == "value" && field == "flow"
        #     return "$(connection.name).flow", JuMP.value.(flow; result=result)
        # elseif mode == "sum" && field == "flow"
        #     return "$(connection.name).sum.flow", sum(JuMP.value.(flow; result=result))
        # end
    else
        if mode == "value" && field == "flow"
            return "$(connection.name).flow", JuMP.value.(connection.var.flow; result=result)
        elseif mode == "sum" && field == "flow"
            return "$(connection.name).sum.flow", sum(JuMP.value.(connection.var.flow; result=result))
        end
    end

    if mode == "dual"
        # todo: JuMP dual result fix
        if result != 1
            @error "Duals are currently only available for the first result (this is a limitation of the JuMP interface)"
        end
        bound, tmp = split(field, ":")
        if tmp != "flow"
            @error "Connection got unknown field for result extraction" connection = connection.name mode = mode field =
                field
            return nothing
        end
        if bound == "ub"
            return "<$(connection.name)>.shadow_price.ub.flow", JuMP.shadow_price.(connection.con.flow_ub)
        elseif bound == "lb"
            return "<$(connection.name)>.shadow_price.lb.flow", JuMP.shadow_price.(connection.con.flow_lb)
        else
            @error "Connection got unknown field for result extraction" connection = connection.name mode = mode field =
                field
            return nothing
        end
    end

    @error "Unknown result extraction" connection = connection.name mode = mode field = field
    return nothing
end

include("connection/exp_pf_flow.jl")
include("connection/var_flow.jl")
include("connection/con_flow_bounds.jl")
include("connection/obj_cost.jl")

function _construct_expressions!(connection::Connection)
    _connection_exp_pf_flow!(connection)
    return nothing
end

function _construct_variables!(connection::Connection)
    _connection_var_flow!(connection)
    return nothing
end

function _after_construct_variables!(connection::Connection)
    # We can now properly finalize the `lb`, `ub`, `capacity`, and `cost`.
    _finalize(connection.lb)
    _finalize(connection.ub)
    _finalize(connection.capacity)
    _finalize(connection.cost)

    return nothing
end

function _construct_constraints!(connection::Connection)
    _connection_con_flow_bounds!(connection)
    return nothing
end

function _construct_objective!(connection::Connection)
    _connection_obj_cost!(connection)
    return nothing
end
