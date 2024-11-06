function _string_to_fevalexpr(@nospecialize(str::AbstractString))
    buf = IOBuffer(; sizehint=length(str))
    it = eachsplit(str, r"(?<=[+\-*/ ()])|(?=[+\-*/ ()])")

    # Instead of interpolating the explicit things a user might access in a string directly into the returned
    # expression, we extract them, and replace them by consecutive placeholders. This way, the function that is
    # generated is always the same, no matter the actual values of the accessed variables, which saves a lot of 
    # re-compilation time. This obviously only works for identical string expressions, that only differ in their
    # accessed terms (e.g., when coming from a template).
    access_order = String[]
    starting_access_index = 1
    extracted_expressions = NamedTuple[]

    for elem in it
        if any(isletter(c) for c in elem)
            if !contains(elem, r"[:|@]")
                e = JuliaSyntax.parsestmt(Expr, String(take!(buf)))

                if length(access_order) >= starting_access_index
                    f = @RuntimeGeneratedFunction(:(function (__el::Vector{Union{Float64, String}})
                        return $e
                    end))
                    push!(extracted_expressions, (name=elem, func=f, elements=access_order[starting_access_index:end]))
                    starting_access_index = length(access_order) + 1
                else
                    value = convert(Float64, eval(e))
                    push!(extracted_expressions, (name=elem, val=value))
                end
            else
                push!(access_order, elem)
                write(buf, "__el[$(length(access_order) - starting_access_index + 1)]")
            end
        else
            write(buf, elem)
        end
    end

    if isempty(extracted_expressions)
        e = JuliaSyntax.parsestmt(Expr, String(take!(buf)))

        if length(access_order) >= starting_access_index
            f = @RuntimeGeneratedFunction(:(function (__el::Vector{Union{Float64, String}})
                return $e
            end))
            push!(extracted_expressions, (name="", func=f, elements=access_order[starting_access_index:end]))
        else
            value = convert(Float64, eval(e))
            push!(extracted_expressions, (name="", val=value))
        end
    end

    return extracted_expressions
end

abstract type _AbstractExpressionType end
struct _GeneralExpressionType <: _AbstractExpressionType end
struct _ConversionExpressionType <: _AbstractExpressionType end

function _parse_expression(@nospecialize(str::AbstractString), ::_GeneralExpressionType)
    return only(_string_to_fevalexpr(str))::NamedTuple
end

function _parse_expression(@nospecialize(str::AbstractString), ::_ConversionExpressionType)
    lhs, rhs = split(str, " -> ")
    return (lhs=(lhs == "~") ? nothing : _string_to_fevalexpr(lhs), rhs=_string_to_fevalexpr(rhs))::NamedTuple
end

"""
    Expression

A mutable struct representing a general expression in the optimization model.

# Fields
- `model::JuMP.Model`: The IESopt model associated with the expression.
- `dirty::Bool`: A flag indicating if the expression is dirty (modified but not updated). Defaults to `false`.
- `temporal::Bool`: A flag indicating if the expression is temporal. Defaults to `false`.
- `empty::Bool`: A flag indicating if the expression is empty. Defaults to `false`.
- `value::Union{Nothing, JuMP.VariableRef, JuMP.AffExpr, Vector{JuMP.AffExpr}, Float64, Vector{Float64}}`: The value of the expression, which can be a JuMP variable reference, affine expression, vector of affine expressions, float, or vector of floats. Defaults to `nothing`.
- `internal::Union{Nothing, NamedTuple}`: Internal data associated with the expression. Defaults to `nothing`.

# Usage examples
```julia
if !my_exp.empty
    # ... do something with `my_exp`, since it contains values ...
end
```

```julia
# Get the Expression's value at Snapshot `t`.
access(my_exp, t)

# Get the Expression's value - could be vector-valued.
access(my_exp)
```

Both ways to access the value can be used with a type assertion to get the value in a specific type:

```julia
# Get the Expression's value at Snapshot `t` as a Float64.
access(my_exp, t, Float64)

# Get the Expression's value as a Float64.
access(my_exp, Float64)
```

If the value of `my_exp` is a vector of `Float64`, the first call will succeed, while the second will throw a type assertion error.
"""
@kwdef mutable struct Expression
    model::JuMP.Model

    dirty::Bool = false
    temporal::Bool = false
    empty::Bool = false

    value::Union{Nothing, JuMP.VariableRef, JuMP.AffExpr, Vector{JuMP.AffExpr}, Float64, Vector{Float64}} = nothing
    internal::Union{Nothing, NamedTuple} = nothing
end

"""
This constant defines a union type `OptionalScalarExpressionValue` which describes any scalar-valued value type that an
Expression can hold. Due to `Optional` it also includes `nothing`.
"""
const OptionalScalarExpressionValue = Union{Nothing, JuMP.VariableRef, JuMP.AffExpr, Float64}

"""
This constant defines a union type `NonEmptyScalarExpressionValue` which describes any scalar-valued type that an
Expression can hold, guaranteeing that the Expression can not be empty.
"""
const NonEmptyScalarExpressionValue = Union{JuMP.VariableRef, JuMP.AffExpr, Float64}

"""
This constant defines a union type `NonEmptyNumericalExpressionValue` which describes any numerical value type that an
Expression can hold, guaranteeing that the Expression can not be empty. `JuMP` objects are not included, and it can be
either scalar or vector-valued.
"""
const NonEmptyNumericalExpressionValue = Union{Float64, Vector{Float64}}

"""
This constant defines a union type `NonEmptyExpressionValue` which describes any value type that an Expression can hold,
guaranteeing that the Expression can not be empty.
"""
const NonEmptyExpressionValue = Union{JuMP.VariableRef, JuMP.AffExpr, Vector{JuMP.AffExpr}, Float64, Vector{Float64}}

_name(e::Expression) = e.empty ? "" : e.internal.name
_isfixed(e::Expression) = (e.empty || (e.value isa Float64) || (e.value isa Vector{Float64}))::Bool
_isempty(e::Expression) = e.empty::Bool

@recompile_invalidations begin
    function Base.show(io::IO, e::Expression)
        str_show = """:: Expression ::"""

        str_show *= "\n├ name: $(_name(e))"
        str_show *= "\n├ dirty: $(e.dirty)"
        str_show *= "\n├ temporal: $(e.temporal)"
        str_show *= "\n├ value type: $(typeof(e.value))"

        if !isnothing(e.internal)
            str_show *= "\n└ internal: $(hasproperty(e.internal, :val) ? e.internal.val : "func($(join(e.internal.elements, ", ")))")"
        else
            str_show *= "\n└ internal: -"
        end

        return print(io, str_show)
    end
end

_convert_to_expression(model::JuMP.Model, ::Nothing) = Expression(; model, empty=true)
_convert_to_expression(model::JuMP.Model, data::Real) = Expression(; model, value=convert(Float64, data))
_convert_to_expression(model::JuMP.Model, data::Vector{<:Real}) =
    Expression(; model, value=convert.(Float64, data), temporal=true)

macro _default_expression(value)
    return esc(:(_convert_to_expression(model, $value)))
end

function _convert_to_expression(model::JuMP.Model, @nospecialize(data::AbstractString))
    parsed = _parse_expression(data, _GeneralExpressionType())

    if hasproperty(parsed, :val)
        return Expression(; model, value=convert(Float64, parsed.val))
    else
        return Expression(; model, internal=parsed, dirty=true)
    end
end

function _convert_to_conversion_expressions(model::JuMP.Model, @nospecialize(data::AbstractString))
    parsed = _parse_expression(data, _ConversionExpressionType())

    expressions = Dict{Symbol, Dict{String, Expression}}(side => Dict{String, Expression}() for side in [:lhs, :rhs])
    for side in [:lhs, :rhs]
        expr = getproperty(parsed, side)
        isnothing(expr) && continue

        for term in expr
            if hasproperty(term, :val)
                expressions[side][term.name] = Expression(; model, value=convert(Float64, term.val))
            else
                expressions[side][term.name] = Expression(; model, internal=term, dirty=true)
                _finalize(expressions[side][term.name])

                # We can finalize immediately here since conversion expressions cannot contain Decision variables, and
                # therefore we know that everything is already accessible (= at most a col@file access).
            end
        end
    end

    return (in=expressions[:lhs], out=expressions[:rhs])
end

function _make_temporal(e::Expression)
    e.temporal && return nothing

    if isnothing(e.value)
        e.value = zeros(Float64, length(get_T(e.model)))
    elseif e.value isa Float64
        e.value = fill(e.value, length(get_T(e.model)))
    else
        if e.value isa JuMP.VariableRef
            e.value = @expression(e.model, e.value)
        end
        e.value = collect(JuMP.AffExpr, copy(e.value) for _ in get_T(e.model))
    end

    e.temporal = true
    return nothing
end

# _get(e::Expression) = e.value
# _get(e::Expression, t::_ID) = (e.value isa Vector) ? e.value[t] : e.value

function prepare(e::Expression; default::Float64)
    if e.empty
        return _convert_to_expression(e.model, default)::Expression
    else
        return e::Expression
    end
end

access(e::Expression) = e.value
function access(e::Expression, t::_ID)
    if e.value isa Vector{JuMP.AffExpr}
        return (e.value::Vector{JuMP.AffExpr})[t]::JuMP.AffExpr
    elseif e.value isa Vector{Float64}
        return (e.value::Vector{Float64})[t]::Float64
    else
        return e.value::Union{Nothing, JuMP.VariableRef, JuMP.AffExpr, Float64}
    end
end
access(e::Expression, @nospecialize(T::Type)) = access(e)::T
access(e::Expression, t::_ID, @nospecialize(T::Type)) = access(e, t)::T

function _finalize(e::Expression)
    e.empty && return nothing
    e.dirty || return nothing

    extraction_names = e.internal.elements
    extractions = []

    for extract in extraction_names
        # TODO: cache this
        if contains(extract, "@")
            col, file = string.(split(extract, "@"))
            # NOTE: Using `identity` here to "downcast" from `Union{Float64, Missing}` to `Float64`.
            push!(extractions, identity.(_getfromcsv(e.model, file, col))::Vector{Float64})
            e.temporal = true
        else
            dec, acc = split(extract, ":")
            # TODO: remove this
            @assert acc == "value"
            push!(extractions, get_component(e.model, dec).var.value)
        end
    end

    if e.temporal
        e.value = [e.internal.func([get_value_at(extract, t) for extract in extractions]) for t in get_T(e.model)]
    else
        e.value = e.internal.func(extractions)
    end

    e.dirty = false
    return nothing
end

_finalize(::Nothing) = nothing

# struct _Expression
#     model::JuMP.Model

#     is_temporal::Bool
#     is_expression::Bool
#     decisions::Union{Nothing, Vector{Tuple{Float64, AbstractString, AbstractString}}}
#     value::Union{JuMP.AffExpr, Vector{JuMP.AffExpr}, Float64, Vector{Float64}}
# end
# const _OptionalExpression = Union{Nothing, _Expression}

# function _get(e::_Expression, t::_ID)
#     if !e.is_temporal
#         if e.is_expression && length(e.value.terms) == 0
#             return e.value.constant
#         end

#         return e.value
#     else
#         t =
#             _iesopt(e.model).model.snapshots[t].is_representative ? t :
#             _iesopt(e.model).model.snapshots[t].representative

#         if e.is_expression && length(e.value[t].terms) == 0
#             return e.value[t].constant
#         end

#         return e.value[t]
#     end
# end

# function _get(e::_Expression)      # todo use this everywhere instead of ***.value
#     if !e.is_expression
#         return e.value
#     end

#     if e.is_temporal
#         if length(e.value[1].terms) == 0
#             if !_has_representative_snapshots(e.model)
#                 return JuMP.value.(e.value)
#             else
#                 return [
#                     JuMP.value(
#                         e.value[(_iesopt(e.model).model.snapshots[t].is_representative ? t :
#                                  _iesopt(e.model).model.snapshots[t].representative)],
#                     ) for t in _iesopt(e.model).model.T
#                 ]
#             end
#         end
#         return e.value
#     else
#         if length(e.value.terms) == 0
#             return e.value.constant
#         end
#         return e.value
#     end
# end

# # This allows chaining without checking for Type in `parser.jl`
# _convert_to_expression(model::JuMP.Model, ::Nothing) = nothing
# _convert_to_expression(model::JuMP.Model, data::Int64) =
#     _Expression(model, false, false, nothing, convert(Float64, data))
# _convert_to_expression(model::JuMP.Model, data::Float64) = _Expression(model, false, false, nothing, data)
# _convert_to_expression(model::JuMP.Model, data::Vector{Int64}) =
#     _Expression(model, true, false, nothing, _snapshot_aggregation!(model, convert(Vector{Float64}, data)))
# _convert_to_expression(model::JuMP.Model, data::Vector{Real}) =
#     _Expression(model, true, false, nothing, _snapshot_aggregation!(model, convert(Vector{Float64}, data)))    # mixed Int64, Float64 vector
# _convert_to_expression(model::JuMP.Model, data::Vector{Float64}) =
#     _Expression(model, true, false, nothing, _snapshot_aggregation!(model, data))

# # todos::
# # - needs to have an option to do it "parametric"
# # - does not handle filecol * decision (for availability with investment) 
# function _convert_to_expression(model::JuMP.Model, str::AbstractString)
#     base_terms = strip.(split(str, "+"))

#     decisions = Vector{Tuple{Float64, AbstractString, AbstractString}}()
#     filecols = Vector{Tuple{Float64, AbstractString, AbstractString}}()
#     constants = Vector{String}()

#     for term in base_terms
#         if occursin(":", term)
#             if occursin("*", term)
#                 coeff, factor = strip.(rsplit(term, "*"; limit=2))
#                 push!(decisions, (_safe_parse(Float64, coeff), eachsplit(factor, ":"; limit=2, keepempty=false)...))
#             else
#                 push!(decisions, (1.0, eachsplit(term, ":"; limit=2, keepempty=false)...))
#             end
#         elseif occursin("@", term)
#             if occursin("*", term)
#                 coeff, file = strip.(rsplit(term, "*"; limit=2))
#                 push!(filecols, (_safe_parse(Float64, coeff), eachsplit(file, "@"; limit=2, keepempty=false)...))
#             else
#                 push!(filecols, (1.0, eachsplit(term, "@"; limit=2, keepempty=false)...))
#             end
#         else
#             push!(constants, term)
#         end
#     end

#     has_decision = length(decisions) > 0
#     has_file = length(filecols) > 0

#     if has_file
#         value = _snapshot_aggregation!(
#             model,
#             sum(fc[1] .* collect(skipmissing(_iesopt(model).input.files[fc[3]][!, fc[2]])) for fc in filecols) .+
#             sum(_safe_parse(Float64, c) for c in constants; init=0.0),
#         )

#         if has_decision
#             return _Expression(model, true, true, decisions, @expression(model, [t = _iesopt(model).model.T], value[t]))
#         else
#             return _Expression(model, true, false, nothing, value)
#         end
#     elseif has_decision
#         return _Expression(
#             model,
#             false,
#             true,
#             decisions,
#             JuMP.AffExpr(sum(_safe_parse(Float64, c) for c in constants; init=0.0)),
#         )
#     else
#         # return _Expression(model, false, true, nothing, JuMP.AffExpr(sum(parse(Float64, c) for c in constants; init=0.0)))
#         # todo: this does not work for `cost: [1, 2, 3]` or similar!
#         return _Expression(model, false, false, nothing, sum(_safe_parse(Float64, c) for c in constants; init=0.0))
#     end
# end

# function _finalize(e::_Expression)
#     # Can not finalize a scalar/vector.
#     !e.is_expression && return nothing

#     # No need to finalize, if there are no `Decision`s involved.
#     isnothing(e.decisions) && return nothing

#     model = e.model

#     # Add all `Decision`s to the inner expression.
#     for (coeff, cname, field) in e.decisions
#         if field == "value"
#             var = _value(get_component(model, cname))
#         elseif field == "size"
#             var = _size(get_component(model, cname))
#         elseif field == "count"
#             var = _count(get_component(model, cname))
#         else
#             @critical "Wrong Decision accessor in unnamed expression" coeff decision = cname accessor = field
#         end

#         JuMP.add_to_expression!.(e.value, var, coeff)
#     end

#     return nothing
# end
