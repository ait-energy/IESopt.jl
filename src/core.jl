# This allows falling back to the `_CoreComponent`'s name for hashing which should enable dictionaries to use the
# `_CoreComponent` as key with a similar performance to using the name as key. This entails that every
# component needs to implement that name - or redefine that function properly.
# See: https://discourse.julialang.org/t/haskey-dict-allocates-when-key-is-a-struct/32093/3
# Further, it seems to be sufficient to overload `isequal` instead of also `Base.:(==)`, see:
# https://stackoverflow.com/a/34939856/5377696; https://github.com/JuliaLang/julia/issues/12198#issuecomment-122938304
# indicates the opposite...
Base.hash(cc::_CoreComponent) = cc.name
Base.:(==)(cc1::_CoreComponent, cc2::_CoreComponent) = cc1.name == cc2.name
Base.isequal(cc1::_CoreComponent, cc2::_CoreComponent) = Base.isequal(cc1.name, cc2.name)

# TODO: replace with https://github.com/KristofferC/TimerOutputs.jl
"""
    @profile(arg1, arg2=nothing)

This macro is used to profile the execution of a function. It captures the time, memory allocation, and number of calls
of the function. The profiling data is stored in the `_profiling` field of the `_IESoptData` structure. The identifier
passed to the macro is used to store the profiling data. If no identifier is provided, the function's name is used as
the identifier.

Options to use this macro are:
    - @profile model "identifier" foo()
    - @profile model foo()
    - @profile "identifier" foo(model)
    - @profile foo(model)
"""
macro profile(arg1, arg2=nothing, arg3=nothing)
    model = nothing

    # Determine if an identifier was provided.
    if arg2 === nothing
        # No identifier provided, parse the function call directly.
        if isa(arg1, Expr) && arg1.head === :call
            base_identifier = arg1.args[1]  # Use function's name as identifier.
            func_call = arg1
            if isa(func_call.args[2], Expr)
                model = esc(func_call.args[3])
            else
                model = esc(func_call.args[2])
            end
        else
            error("Invalid macro usage. Expected a function call.")
        end
    else
        # Identifier (and/or model) provided.
        if isa(arg1, String)
            base_identifier = arg1
            func_call = arg2
            if isa(func_call.args[2], Expr)
                model = esc(func_call.args[3])
            else
                model = esc(func_call.args[2])
            end
        else #if isa(arg1, JuMP.Model)
            model = esc(arg1)
            if isa(arg2, String)
                base_identifier = arg2
                func_call = arg3
            else
                base_identifier = arg2.args[1]
                func_call = arg2
            end
        end
    end

    # Extract the function and its arguments from the func_call expression.
    if !(isa(func_call, Expr) && func_call.head === :call)
        error("The macro expects a function call.")
    end

    func = func_call.args[1]
    args = esc.(func_call.args[2:end])

    # Generate code that runs the function within the @timed macro, capturing the profiling and saving it.
    quote
        local profile, profiling, identifier, method

        method = methods($func)[1]
        identifier = (Symbol(method.module), string(method.file), Symbol($base_identifier))

        profiling = _iesopt($model).aux._profiling
        profile = @timed $func($(args...))

        if haskey(profiling, identifier)
            profiling[identifier].time += profile.time
            profiling[identifier].bytes += profile.bytes
            profiling[identifier].calls += 1
        else
            profiling[identifier] = _Profiling(profile.time, profile.bytes, 1)
        end

        profile.value  # Return the function's return value.
    end
end

include("core/carrier.jl")
include("core/expression.jl")   # this needs to come before the core components using it
include("core/connection.jl")
include("core/decision.jl")
include("core/node.jl")
include("core/profile.jl")
include("core/snapshot.jl")
include("core/unit.jl")

# Finalize the docstrings of the core components.
_finalize_docstring(Connection)
_finalize_docstring(Decision)
_finalize_docstring(Node)
_finalize_docstring(Profile)
_finalize_docstring(Unit)

# Here, empty implementations are done to ensure every core component type implements all necessary functionality, even
# if it does not care about that. Make sure to implement them, in order to actually use them.
_check(cc::_CoreComponent) = !cc.conditional
function _prepare!(::_CoreComponent) end
function _isvalid(cc::_CoreComponent)
    @warn "_isvalid(...) not implemented" cc_type = typeof(cc)
    return true
end
function _setup!(::_CoreComponent) end
function _result(::_CoreComponent, ::String, ::String; result::Int=1) end
function _to_table(component::_CoreComponent)
    excluded_fields = (
        :model,
        :init_state,
        :config,
        :ext,
        :addon,
        :results,
        :terms,
        :conversion_dict,
        :conversion_at_min_dict,
        :capacity_carrier,
        :marginal_cost_carrier,
        :total,
    )

    _hp = function (x)
        if (x isa Number) || (x isa AbstractString) || (x isa Symbol)
            return x
        elseif x isa Carrier
            return x.name
        elseif x isa AbstractVector
            return "[...]"
        else
            return "__presolved__"
        end
    end

    return OrderedDict{Symbol, Any}(
        field => (isnothing(getfield(component, field)) ? missing : _hp(getfield(component, field))) for
        field in fieldnames(typeof(component)) if
        !((field in excluded_fields) || contains(String(field), r"var_|constr_|expr_|obj_"))
    )
end
function _construct_expressions!(::_CoreComponent) end
function _after_construct_expressions!(::_CoreComponent) end
function _construct_variables!(::_CoreComponent) end
function _after_construct_variables!(::_CoreComponent) end
function _construct_constraints!(::_CoreComponent) end
function _after_construct_constraints!(::_CoreComponent) end
function _construct_objective!(::_CoreComponent) end

function filter_component(model::JuMP.Model, tags::Vector{String})
    @error "Filtering based on tags has been deprecated"
    return nothing
end

function _result_fields(component::_CoreComponent)
    @error "_result_fields(...) not implemented" component = component.name
    return nothing
end

_component_type(::_CoreComponent) = nothing
_component_type(::Connection) = :Connection
_component_type(::Decision) = :Decision
_component_type(::Node) = :Node
_component_type(::Profile) = :Profile
_component_type(::Unit) = :Unit

_build_priority(cc::_CoreComponent) = _build_priority(cc.build_priority, 0.0)
_build_priority(::Nothing, default) = default
_build_priority(priority::Real, ::T) where {T} = convert(T, priority)
_build_priority(priority, ::Any) = @error "Unsupported build priority" priority

function Base.getproperty(cc::_CoreComponent, field::Symbol)
    try
        (field == :var) && (return getfield(cc, :_ccoc).variables)
        (field == :con) && (return getfield(cc, :_ccoc).constraints)
        (field == :exp) && (return getfield(cc, :_ccoc).expressions)
        (field == :obj) && (return getfield(cc, :_ccoc).objectives)
        return getfield(cc, field)
    catch e
        @critical "Field not found in _CoreComponent" e
    end
end

function Base.propertynames(cc::_CoreComponent)
    return (propertynames(cc)..., :exp, :var, :con, :obj)
end

function Base.getproperty(ccocd::_CoreComponentOptContainerDict, field::Symbol)
    try
        return getfield(ccocd, :dict)[field]
    catch e
        @critical "Field not found in _CoreComponentOptContainerDict" e
    end
end

function Base.setproperty!(ccocd::_CoreComponentOptContainerDict, field::Symbol, value)
    return getfield(ccocd, :dict)[field] = value
end

function Base.setindex!(ccocd::_CoreComponentOptContainerDict, value, field::Symbol)
    return getfield(ccocd, :dict)[field] = value
end

function Base.getindex(ccocd::_CoreComponentOptContainerDict, field::Symbol)
    return getfield(ccocd, :dict)[field]
end

function Base.keys(ccocd::_CoreComponentOptContainerDict)
    return keys(getfield(ccocd, :dict))
end

# function Base.getproperty(ccoc::_CoreComponentOptContainer, field::Symbol)
#     (field == :var) && (return getfield(ccoc, :variables))
#     (field == :con) && (return getfield(ccoc, :constraints))
#     (field == :exp) && (return getfield(ccoc, :expressions))
#     (field == :obj) && (return getfield(ccoc, :objectives))

#     throw(ArgumentError("Field $field not found in _CoreComponentOptContainer"))
# end

# function Base.setproperty!(ccoc::_CoreComponentOptContainer, field::Symbol, value)
#     getfield(ccoc, :content)[field] = value
# end

# function Base.propertynames(ccoc::_CoreComponentOptContainer)
#     return propertynames(getfield(ccoc, :content))
# end

@kwdef struct _CoreComponentOptResultContainer
    expressions = _CoreComponentOptContainerDict{Union{Float64, Vector{Float64}}}()
    variables = _CoreComponentOptContainerDict{Union{Float64, Vector{Float64}}}()
    constraints = _CoreComponentOptContainerDict{Union{Float64, Vector{Float64}}}()
    objectives = _CoreComponentOptContainerDict{Float64}()

    results = _CoreComponentOptContainerDict{Union{Float64, Vector{Float64}}}()
end

struct _CoreComponentResult <: _CoreComponent
    _info::Dict{Symbol, Any}
    _ccorc::_CoreComponentOptResultContainer
end

function Base.getproperty(ccr::_CoreComponentResult, field::Symbol)
    try
        (field == :var) && (return getfield(ccr, :_ccorc).variables)
        (field == :con) && (return getfield(ccr, :_ccorc).constraints)
        (field == :exp) && (return getfield(ccr, :_ccorc).expressions)
        (field == :obj) && (return getfield(ccr, :_ccorc).objectives)
        (field == :res) && (return getfield(ccr, :_ccorc).results)
        return getfield(ccr, :_info)[field]
    catch e
        @critical "Field not found in _CoreComponentResult" e
    end
end

function Base.propertynames(ccr::_CoreComponentResult)
    return (propertynames(ccr)..., :exp, :var, :con, :obj, keys(getfield(ccr, :_info))...)
end

_hasexp(cc::_CoreComponent, name::Symbol) = haskey(getfield(getfield(cc, :_ccoc).expressions, :dict), name)
_hasvar(cc::_CoreComponent, name::Symbol) = haskey(getfield(getfield(cc, :_ccoc).variables, :dict), name)
_hascon(cc::_CoreComponent, name::Symbol) = haskey(getfield(getfield(cc, :_ccoc).constraints, :dict), name)
_hasobj(cc::_CoreComponent, name::Symbol) = haskey(getfield(getfield(cc, :_ccoc).objectives, :dict), name)
_hasres(cc::_CoreComponent, name::Symbol) = haskey(getfield(getfield(cc, :_ccoc).results, :dict), name)

mutable struct _Profiling
    time::Float64
    bytes::Int
    calls::Int
end

mutable struct _IESoptInputData
    config::Union{_Config, Nothing}
    files::Dict{String, Union{Module, DataFrames.DataFrame}}
    addons::Dict{Any, Any}      # todo

    noncore::Dict{Symbol, Any}
    stochastic::Dict{Symbol, Dict}
    parameters::Dict{String, Any}

    _tl_yaml::Dict{String, Any}
end

mutable struct _IESoptModelData
    T::Vector{_ID}
    components::Dict{String, _CoreComponent}
    objectives::Dict{String, NamedTuple}

    snapshots::Dict{_ID, Snapshot}
    carriers::Dict{String, Carrier}
end

mutable struct _IESoptAuxiliaryData
    constraint_safety_penalties::Dict{JuMP.ConstraintRef, NamedTuple}
    constraint_safety_expressions::Any      # todo
    etdf::NamedTuple
    _flattened_description::Dict{String, Any}
    _obj_terms::Dict{String, Vector{Union{String, Float64}}}
    _profiling::Dict{Tuple{Symbol, String, Symbol}, _Profiling}
    cache::Dict{Symbol, Any}
end

mutable struct _IESoptResultData
    components::Dict{String, _CoreComponentResult}
    objectives::Dict{String, Float64}
    customs::Dict{Symbol, Union{Float64, Vector{Float64}}}
    _templates::Dict{String, Any}
end

mutable struct _IESoptData
    input::_IESoptInputData
    model::_IESoptModelData

    results::_IESoptResultData

    logger::Union{AbstractLogger, Nothing}
    debug::Any    # todo: @stacktrace(model, "optional msg")     inserts a stacktrace into the debug field incl. the current function

    aux::_IESoptAuxiliaryData

    # auxiliary_objective_sc # todo: remove from doc
end

function _IESoptInputData(toplevel_yaml::Dict)
    return _IESoptInputData(
        nothing,
        Dict{String, Union{Module, DataFrames.DataFrame}}(),
        Dict{Any, Any}(),
        Dict{Symbol, Any}(),
        Dict{Symbol, Any}(),
        Dict{String, Any}(),
        toplevel_yaml,
    )
end

function _IESoptModelData()
    return _IESoptModelData(
        Vector{_ID}(),
        Dict{String, _CoreComponent}(),
        Dict{String, NamedTuple{(:terms, :expr), Tuple{Set{JuMP.AffExpr}, JuMP.AffExpr}}}(),
        Dict{_ID, Snapshot}(),
        Dict{String, Carrier}(),
    )
end

function _IESoptAuxiliaryData()
    return _IESoptAuxiliaryData(
        Dict{JuMP.ConstraintRef, NamedTuple}(),
        nothing,
        (groups=Dict{String, Vector{_ID}}(), constr=Dict{String, Vector{JuMP.ConstraintRef}}()),
        Dict{String, Any}(),
        Dict{String, Vector{Union{String, Float64}}}(),
        Dict{Tuple{Symbol, String, Symbol}, _Profiling}(),
        Dict{Symbol, Any}(),
    )
end

function _IESoptResultData()
    return _IESoptResultData(
        Dict{String, _CoreComponentResult}(),
        Dict{String, Float64}(),
        Dict{Symbol, Union{Float64, Vector{Float64}}}(),
        Dict{String, Any}(),
    )
end

function _IESoptData(toplevel_yaml::Dict)
    return _IESoptData(
        _IESoptInputData(toplevel_yaml),
        _IESoptModelData(),
        _IESoptResultData(),
        nothing,
        nothing,
        _IESoptAuxiliaryData(),
    )
end

_iesopt(model::JuMP.Model) = model.ext[:iesopt]
_iesopt_config(model::JuMP.Model) = _iesopt(model).input.config
_iesopt_debug(model::JuMP.Model) = _iesopt(model).debug     # TODO: as soon as debug is a "stack", only report the last entry in this function
_iesopt_cache(model::JuMP.Model) = _iesopt(model).aux.cache
_iesopt_model(model::JuMP.Model) = _iesopt(model).model

_has_addons(model::JuMP.Model) = !isempty(_iesopt(model).input.addons)

_has_cache(model::JuMP.Model, cache::Symbol) = haskey(_iesopt_cache(model), cache)
_get_cache(model::JuMP.Model, cache::Symbol) = _iesopt_cache(model)[cache]

function _is_cached(model::JuMP.Model, cache::Symbol, entry::Any)
    return _has_cache(model, cache) && haskey(_iesopt_cache(model)[cache], entry)
end
_get_cached(model::JuMP.Model, cache::Symbol, entry::Any) = _iesopt_cache(model)[cache][entry]
