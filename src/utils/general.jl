abstract type _CoreComponent end

@kwdef struct _CoreComponentOptContainerDict{T <: Any}
    dict::Dict{Symbol, T} = Dict{Symbol, T}()
end

@kwdef struct _CoreComponentOptContainer
    expressions = _CoreComponentOptContainerDict{Union{JuMP.AffExpr, Vector}}()
    variables = _CoreComponentOptContainerDict{Union{JuMP.VariableRef, Vector}}()
    constraints = _CoreComponentOptContainerDict{Union{JuMP.ConstraintRef, Vector}}()       # TODO: this clashes with a more specific definition of `ConstraintRef` in JuMP
    objectives = _CoreComponentOptContainerDict{JuMP.AffExpr}()
end

"""
    _AbstractVarRef

Hold an unsolved reference onto a `JuMP.VariableRef`, that was not fully available before components were initialized.
"""
struct _AbstractVarRef
    comp_name::String
    field::Symbol
end

"""
    _PresolvedVarRef

Hold a presolved reference onto a `JuMP.VariableRef`, that was not fully available before components were initialized.
"""
struct _PresolvedVarRef
    comp::_CoreComponent
    field::Function
end

struct _AbstractAffExpr
    constant::Float64
    variables::Vector{NamedTuple{(:coeff, :var), Tuple{Float64, _AbstractVarRef}}}
end

struct _PresolvedAffExpr
    constant::Float64
    variables::Vector{NamedTuple{(:coeff, :var), Tuple{Float64, _PresolvedVarRef}}}
end

# _ID is used for all internal "ids". To ensure proper access, all ids need to be >= 1, unique and dense
const _ID = Int64
# This defines the `_NumericalInput` type, that is used by IESopt for numerical input data (`Profile` values, ...)
const _NumericalInput = Union{Number, AbstractVector{<:Number}, _CoreComponent}   # todo: this should be Expression (which we don't know here...)
# This defines the `_ScalarInput` type, a scalar (non-vector) type for numerical input data.
const _ScalarInput = Union{Number}
# A `_NumericalInput` type that allows passing `nothing`.
const _OptionalNumericalInput = Union{_NumericalInput, Nothing}
# A `_ScalarInput` type that allows passing `nothing`.
const _OptionalScalarInput = Union{_ScalarInput, Nothing}

# A bound that can be given either by a `_NumericalInput` or defined based on variable in another core component.
const _Bound = Union{_NumericalInput, _AbstractAffExpr, _PresolvedAffExpr}
# A `_Bound` type that allows passing `nothing`.
const _OptionalBound = Union{_Bound, Nothing}

# All strings in IESopt use this type.
const _String = AbstractString #CSV.InlineStrings.AbstractString
const _OptionalString = Union{_String, Nothing}

_get(::Nothing) = nothing
_get(::Nothing, t::_ID) = nothing
_get(bound::_ScalarInput) = bound
_get(bound::_ScalarInput, t::_ID) = bound

# todo: this is potentially unoptimized since the binding is not constant
#       see: https://stackoverflow.com/a/34023458/5377696
# this comment was related to: https://gitlab-intern.ait.ac.at/energy/commons/marketflow/core/-/blob/6d54998118a91b18b8d58846745be636890ec815/src/utils.jl#L54
function _get(bound::_PresolvedAffExpr)
    return sum(coeff * var.field(var.comp) for (coeff, var) in bound.variables; init=bound.constant)
end

# todo: is there a case where decisions will be "per snapshot"?
function _get(bound::_PresolvedAffExpr, t::_ID)
    return sum(coeff * var.field(var.comp, t) for (coeff, var) in bound.variables; init=bound.constant)
end

function _safe_parse(::Type{Float64}, str::AbstractString)
    ret = tryparse(Float64, str)
    if !isnothing(ret)
        return ret
    end
    return eval(Meta.parse(str))
end

"""
This is due to slow and expensive expression building in loops. For a description of this see [^1]; [^2] further
addresses this. The implementation is based on [^3] and [^4].

[^1]: https://discourse.julialang.org/t/jump-cplex-adding-objective-function-expression-in-loop-is-very-resource-consuming/21859/3
[^2]: https://github.com/JuliaOpt/GSOC2019/blob/master/ideas-list.md#mutablearithmetics
[^3]: https://github.com/jump-dev/JuMP.jl/blob/f46a461c126fd1a7c309fb773a00b5dc529632b9/src/operators.jl#L304-L310 and
[^4]: https://github.com/Spine-project/SpineOpt.jl/blob/ba695b6af802286a36f6f97758ff99cd5c324f94/src/util/misc.jl#L85-L93
"""
function _affine_expression(elements; init::Float64=0.0)
    if isa(elements, Base.Generator)
        elements
    end

    if isa(init, Number)
        expr = JuMP.AffExpr(init)
    else
        expr = zero(T)
        expr += init
    end
    isempty(elements) && return expr
    expr += first(elements)
    for element in Iterators.drop(elements, 1)
        JuMP.add_to_expression!(expr, element)
    end

    return expr
end

"""
    _get(numerical_input::_NumericalInput, t::UInt)

Get the value of the `numerical_input` at time (snapshot index) `t`.
"""
# _get(x::Number, t::UInt) = x  # this is already done above (see `ScalarInput`)
_get(x::AbstractVector{<:Number}, t::_ID) = x[t]
_get(x::JuMP.AffExpr, t::_ID) = x
_get(x::Vector{JuMP.AffExpr}, t::_ID) = x[t]

function _mapexpr_addon(expr::Expr, reload::Bool)
    if expr.head != :module
        # First code is not a module definition.
        error("Failed loading addon (ERROR_CODE 1); make sure the file only contains a single module definition that wraps all your code")
    end

    if length(expr.args) != 3
        # Too many (or not enough) code blocks in the file.
        error("Failed loading addon (ERROR_CODE 2); make sure the file only contains a single module definition that wraps all your code")
    end

    if expr.args[3].head != :block
        # The actual stuff inside the module defintion is not a block.
        error("Failed loading addon (ERROR_CODE 3); make sure the file only contains a single module definition that wraps all your code")
    end

    module_name = expr.args[2]

    if reload
        if (module_name in names(@__MODULE__; all=true)) || (module_name in names(Main; all=true))
            @info "Replacing existing addon" addon = module_name
        end

        return nothing
    end

    if module_name in names(@__MODULE__; all=true)
        # Addon already loaded in IESopt.
        @info "Addon already loaded" addon = module_name
        return Meta.parse(string(module_name))
    end

    if module_name in names(Main; all=true)
        # Addon already loaded in Main.
        @info "Addon already loaded in global Main" addon = module_name
        return Meta.parse("Main.$(module_name)")
    end

    return nothing
end

function _load_or_retrieve_addon_file(filename::String; reload::Bool)
    try
        module_addon = include((e) -> _mapexpr_addon(e, reload), filename)

        if module_addon isa Module
            return module_addon
        elseif isnothing(module_addon)
            # We did not get a module back, but no error was generated. This means we are fine to just include the file.
            # This `include(...)` could trigger a warning about reloading the module, which we now suppress.
            module_addon = @suppress include(filename)
            (module_addon isa Module) && return module_addon
        end

        @error "An error occured while trying to load an addon file" addon_file_name = filename
        @error "The loaded code did not return a valid module; make sure the file only contains a single module definition that wraps all your code"
    catch e
        @error "An error occured while trying to load an addon file" addon_file_name = filename
        @error string(e.error)
        @error "The error seems to have occured here" file = e.file line = e.line
    end

    @critical "Error while loading addons, see above for details"
end

function _getfile(model::JuMP.Model, filename::String; path::Symbol=:auto, sink=DataFrames.DataFrame, slice::Bool=true)
    if endswith(filename, ".csv")
        path = path === :auto ? :files : path
        filepath = abspath(getfield(_iesopt_config(model).paths, path), filename)
        return _getcsv(model, filepath; sink=sink, slice=slice)
    elseif endswith(filename, ".jl")
        path = path === :auto ? :addons : path
        core_addon_dir = _PATHS[:addons]
        filepath_local = abspath(getfield(_iesopt_config(model).paths, path), filename)
        filepath_core = abspath(core_addon_dir, filename)

        # Before checking the file, let's see if it refers to an already loaded module instead.
        # This requires you to pass the EXACT name of the module as addon name!
        module_name = Symbol(basename(filename)[1:(end-3)])
        if (module_name in names(Main; all=true))
            @info "Addon already loaded in global Main" addon = module_name
            if model.ext[:_iesopt_force_reload]
                @warn "Cannot force reload an addon that is already loaded in Main, outside IESopt; ignoring reload, and re-using the existing module" module_name
            end
            return getfield(Main, module_name)
        end

        if isfile(filepath_local)
            @info "Trying to load addon from file (local)" filename source = filepath_local
            return _load_or_retrieve_addon_file(filepath_local; reload=model.ext[:_iesopt_force_reload])
        elseif isfile(filepath_core)
            @info "Trying to load addon from file (core)" filename source = filepath_core
            return _load_or_retrieve_addon_file(filepath_core; reload=model.ext[:_iesopt_force_reload])
        else
            @critical "Failed to find addon location" filename filepath_local filepath_core
        end
    end
end

"""
    _getcsv(filename::String; sep::String=",")

Read a CSV into a DataFrame.
"""
function _getcsv(
    model::JuMP.Model,
    filename::String;
    sep::String=",",
    dec::Char='.',
    sink=DataFrames.DataFrame,
    slice::Bool,
)
    @info "Trying to load CSV" filename

    # Read the entire file. CSV.jl's `skipto` only makes it worse.
    # See: https://github.com/JuliaData/CSV.jl/issues/959
    table = CSV.read(filename, sink; delim=sep, stringtype=String, decimal=dec)

    # If we are not slicing we return the whole table
    slice || return table

    # Get some snapshot config parameters
    offset = _iesopt_config(model).optimization.snapshots.offset
    aggregation = _iesopt_config(model).optimization.snapshots.aggregate

    # Offset and aggregation don't work together.
    if !isnothing(aggregation) && offset != 0
        @critical "Snapshot aggregation and non-zero offsets are currently not supported"
    end

    # Get the number of table rows and and the model's snapshot count
    nrows = size(table, 1)
    count = _iesopt_config(model).optimization.snapshots.count

    # Get the range of table rows we want to return.
    # Without snapshot aggregation we can return the rows specified by offset and count.
    # Otherwise, we start at 1 and multiply the number of rows to return by the number of snapshots to aggregate.
    from, to = isnothing(aggregation) ? (offset + 1, offset + count) : (1, count * aggregation)

    # Check if the range of rows is in bounds.
    if from < 1 || to > nrows || from > to
        @critical "Trying to access data with out-of-bounds or empty range" filename from to nrows
    end

    return table[from:to, :]
end

function _getfromcsv(model::JuMP.Model, file::String, column::String)
    haskey(_iesopt(model).input.files, file) || (@critical "File not properly registered" column file)
    return @view _iesopt(model).input.files[file][_iesopt(model).model.T, column]
end

function _conv_S2NI(model::JuMP.Model, str::AbstractString)
    # This handles pure values like "2.0".
    val = tryparse(Float64, str)
    !isnothing(val) && return val

    if isnothing(findfirst("@", str))
        # Check if this is a link to an Expression.
        if haskey(_iesopt(model).model.components, str)
            component = component(model, str)
            error(
                "You ended up in an outdated part of IESopt, which should not have happened. Please report this error including the model you are trying to run.",
            )
            # todo: check this (which does not work currently since Expression is not defined at this point)
            # if !(component isa Expression)
            #     @error "Non Expression component can not be converted to NumericalInput" str = str
            # end
            return component
        else
            # This handles calculations like "1/0.9".
            return eval(Meta.parse(str))
        end
    else
        # This handles references to files like "column@data_file".
        col, file = split(str, "@")
        return collect(skipmissing(_iesopt(model).input.files[file][!, col]))
    end
end

# AbstractString is necessary for also accepting SubString

function _presolve(model::JuMP.Model, data::_OptionalNumericalInput)
    return data
end

function _presolve(model::JuMP.Model, data::_AbstractAffExpr)
    # For `var` as one of the variables:
    # `var.field` contains the "variable" that we want to query. That is e.g. "value". The previous call to
    # `_conv_S2AbstractVarRef` converted that into `:_value` which we query from IESopt (which is a function
    # that can be used to extract the value of a Decision component).
    return _PresolvedAffExpr(
        data.constant,
        [
            (coeff=coeff, var=_PresolvedVarRef(component(model, var.comp_name), getfield(IESopt, var.field))) for
            (coeff, var) in data.variables
        ],
    )
end

# Needed to safely parse booleans (like "not true") that can result from parameter replacements.
function _parse_bool(model::JuMP.Model, str::String)::Bool
    if !_has_cache(model, :parse_bool)
        _iesopt_cache(model)[:parse_bool] =
            Dict{String, Bool}("true" => true, "false" => false, "not true" => false, "not false" => true)
    end

    _is_cached(model, :parse_bool, str) && return _get_cached(model, :parse_bool, str)

    try
        parsed = eval(_unknown_to_string(model, Meta.parse(str)))
        _iesopt_cache(model)[:parse_bool][str] = parsed
        return parsed
    catch e
        @critical "Cannot convert string to bool" str
    end
end
_parse_bool(::JuMP.Model, b::Bool) = b

_unknown_to_string(::JuMP.Model, x) = x
function _unknown_to_string(model::JuMP.Model, ex::Expr)
    return Expr(ex.head, (_unknown_to_string(model::JuMP.Model, arg) for arg in ex.args)...)
end
function _unknown_to_string(model::JuMP.Model, sym::Symbol)::Union{Symbol, String}
    if !_has_cache(model, :module_names)
        _iesopt_cache(model)[:module_names] = union(Set{Symbol}(names(Core)), names(Base), names(IESopt))
    end

    sym in _get_cache(model, :module_names) && return sym
    return string(sym)
end

function _base_name(comp::_CoreComponent, str::String)
    !JuMP.set_string_names_on_creation(comp.model) && return ""
    return "$(comp.name).$str"
end

# These are used in Benders and Stochastic.
_obj_type(::Any) = :other
_obj_type(::JuMP.VariableRef) = :var
_obj_type(::Vector{JuMP.VariableRef}) = :var
_obj_type(::JuMP.Containers.DenseAxisArray{JuMP.VariableRef}) = :var
_obj_type(::JuMP.Containers.SparseAxisArray{JuMP.VariableRef}) = :var
function _print_iteration(k, args...)
    _format = (val) -> Printf.@sprintf("%12.4e", val)
    return println(lpad(k, 7), "  |", join(_format.(args), "  |"))
end

_allmissing(::Missing) = true
_allmissing(x) = all(ismissing, x)
_anymissing(::Missing) = true
_anymissing(x) = any(ismissing, x)
_allval(x) = !_anymissing(x)
_anyval(x) = !_allmissing(x)

function _add_obj_term!(model::JuMP.Model, term::String; component::String, objective::String)
    return _add_obj_term_from_str!(model, Meta.parse(term); component=component, objective=objective)
end

function _add_obj_term!(model::JuMP.Model, term::Number; component::String, objective::String)
    push!(_iesopt(model).aux._obj_terms[objective], float(term))
    return nothing
end

function _add_obj_term_from_str!(model::JuMP.Model, parsed_term::Expr; component::String, objective::String)
    try
        push!(_iesopt(model).aux._obj_terms[objective], eval(parsed_term))
    catch error
        @critical "Failed to evaluate objective term" component objective error
    end
    return nothing
end

function _add_obj_term_from_str!(model::JuMP.Model, parsed_term::Symbol; component::String, objective::String)
    push!(_iesopt(model).aux._obj_terms[objective], "$(component).$(parsed_term)")
    return nothing
end

function _profiling_get_top(model::JuMP.Model, n::Int64; mode::Symbol=:time, groupby::Symbol=:function)
    prof = _iesopt(model).aux._profiling

    if groupby == :function
        data = prof
    elseif groupby == :module
        groups = Set(it[1] for it in keys(prof))
        data = Dict(
            g => _Profiling(
                sum(v.time for (k, v) in prof if k[1] == g),
                sum(v.bytes for (k, v) in prof if k[1] == g),
                sum(v.calls for (k, v) in prof if k[1] == g),
            ) for g in groups
        )
    elseif groupby == :file
        groups = Set(it[1:2] for it in keys(prof))
        data = Dict(
            g => _Profiling(
                sum(v.time for (k, v) in prof if k[1:2] == g),
                sum(v.bytes for (k, v) in prof if k[1:2] == g),
                sum(v.calls for (k, v) in prof if k[1:2] == g),
            ) for g in groups
        )
    end

    return sort(collect(data); by=x -> getfield(x[2], mode), rev=true)[1:(min(n, length(data)))]
end

function _profiling_format_top(model::JuMP.Model, n::Int64=5; mode::Symbol=:time)
    data = _profiling_get_top(model, n; mode=mode, groupby=:function)
    return OrderedDict(
        Symbol("func: $(it.first[3]) @ $(splitpath(it.first[2])[end]) ($(it.first[1]))") => getfield(it.second, mode)
        for it in data
    )
end

_is_valid_template_name(s::String) = !isnothing(match(r"""^[A-Z][A-Za-z]+$""", s))
_is_valid_component_name(s::String) = !isnothing(match(r"""^[a-z][a-z_.0-9]*[a-z0-9]$""", s))
