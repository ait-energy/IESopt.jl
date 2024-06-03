struct _Expression
    model::JuMP.Model

    is_temporal::Bool
    is_expression::Bool
    decisions::Union{Nothing, Vector{Tuple{Float64, AbstractString, AbstractString}}}
    value::Union{JuMP.AffExpr, Vector{JuMP.AffExpr}, Float64, Vector{Float64}}
end
const _OptionalExpression = Union{Nothing, _Expression}

function _get(e::_Expression, t::_ID)
    if !e.is_temporal
        if e.is_expression && length(e.value.terms) == 0
            return e.value.constant
        end

        return e.value
    else
        t =
            _iesopt(e.model).model.snapshots[t].is_representative ? t :
            _iesopt(e.model).model.snapshots[t].representative

        if e.is_expression && length(e.value[t].terms) == 0
            return e.value[t].constant
        end

        return e.value[t]
    end
end

function _get(e::_Expression)      # todo use this everywhere instead of ***.value
    if !e.is_expression
        return e.value
    end

    if e.is_temporal
        if length(e.value[1].terms) == 0
            if !_has_representative_snapshots(e.model)
                return JuMP.value.(e.value)
            else
                return [
                    JuMP.value(
                        e.value[(_iesopt(e.model).model.snapshots[t].is_representative ? t :
                                 _iesopt(e.model).model.snapshots[t].representative)],
                    ) for t in _iesopt(e.model).model.T
                ]
            end
        end
        return e.value
    else
        if length(e.value.terms) == 0
            return e.value.constant
        end
        return e.value
    end
end

# This allows chaining without checking for Type in `parser.jl`
_convert_to_expression(model::JuMP.Model, ::Nothing) = nothing
_convert_to_expression(model::JuMP.Model, data::Int64) =
    _Expression(model, false, false, nothing, convert(Float64, data))
_convert_to_expression(model::JuMP.Model, data::Float64) = _Expression(model, false, false, nothing, data)
_convert_to_expression(model::JuMP.Model, data::Vector{Int64}) =
    _Expression(model, true, false, nothing, _snapshot_aggregation!(model, convert(Vector{Float64}, data)))
_convert_to_expression(model::JuMP.Model, data::Vector{Real}) =
    _Expression(model, true, false, nothing, _snapshot_aggregation!(model, convert(Vector{Float64}, data)))    # mixed Int64, Float64 vector
_convert_to_expression(model::JuMP.Model, data::Vector{Float64}) =
    _Expression(model, true, false, nothing, _snapshot_aggregation!(model, data))

# todos::
# - needs to have an option to do it "parametric"
# - does not handle filecol * decision (for availability with investment) 
function _convert_to_expression(model::JuMP.Model, str::AbstractString)
    base_terms = strip.(split(str, "+"))

    decisions = Vector{Tuple{Float64, AbstractString, AbstractString}}()
    filecols = Vector{Tuple{Float64, AbstractString, AbstractString}}()
    constants = Vector{String}()

    for term in base_terms
        if occursin(":", term)
            if occursin("*", term)
                coeff, factor = strip.(rsplit(term, "*"; limit=2))
                push!(decisions, (_safe_parse(Float64, coeff), eachsplit(factor, ":"; limit=2, keepempty=false)...))
            else
                push!(decisions, (1.0, eachsplit(term, ":"; limit=2, keepempty=false)...))
            end
        elseif occursin("@", term)
            if occursin("*", term)
                coeff, file = strip.(rsplit(term, "*"; limit=2))
                push!(filecols, (_safe_parse(Float64, coeff), eachsplit(file, "@"; limit=2, keepempty=false)...))
            else
                push!(filecols, (1.0, eachsplit(term, "@"; limit=2, keepempty=false)...))
            end
        else
            push!(constants, term)
        end
    end

    has_decision = length(decisions) > 0
    has_file = length(filecols) > 0

    if has_file
        value = _snapshot_aggregation!(
            model,
            sum(fc[1] .* collect(skipmissing(_iesopt(model).input.files[fc[3]][!, fc[2]])) for fc in filecols) .+
            sum(_safe_parse(Float64, c) for c in constants; init=0.0),
        )

        if has_decision
            return _Expression(model, true, true, decisions, @expression(model, [t = _iesopt(model).model.T], value[t]))
        else
            return _Expression(model, true, false, nothing, value)
        end
    elseif has_decision
        return _Expression(
            model,
            false,
            true,
            decisions,
            JuMP.AffExpr(sum(_safe_parse(Float64, c) for c in constants; init=0.0)),
        )
    else
        # return _Expression(model, false, true, nothing, JuMP.AffExpr(sum(parse(Float64, c) for c in constants; init=0.0)))
        # todo: this does not work for `cost: [1, 2, 3]` or similar!
        return _Expression(model, false, false, nothing, sum(_safe_parse(Float64, c) for c in constants; init=0.0))
    end
end

function _finalize(e::_Expression)
    # Can not finalize a scalar/vector.
    !e.is_expression && return nothing

    # No need to finalize, if there are no `Decision`s involved.
    isnothing(e.decisions) && return nothing

    model = e.model

    # Add all `Decision`s to the inner expression.
    for (coeff, cname, field) in e.decisions
        if field == "value"
            var = _value(component(model, cname))
        elseif field == "size"
            var = _size(component(model, cname))
        elseif field == "count"
            var = _count(component(model, cname))
        else
            @critical "Wrong Decision accessor in unnamed expression" coeff decision = cname accessor = field
        end

        JuMP.add_to_expression!.(e.value, var, coeff)
    end

    return nothing
end
