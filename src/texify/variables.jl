struct _VariableInfo10
    name::Symbol
    indices::Vector{Int64}
    is_binary::Bool
    is_integer::Bool
    is_fixed::Bool
    lower_bound::Union{Nothing, Float64}
    upper_bound::Union{Nothing, Float64}
    fix_values::Vector{Float64}
    # todo: this assumes that a variable is either binary/integer/fixed for ALL indices or for NONE
end
_VariableInfo = _VariableInfo10

function _describe_variables(model::JuMP.Model; prefix::String="")
    variables = JuMP.all_variables(model)

    parents = Dict{String, Dict{Symbol, _VariableInfo}}()
    for var in variables
        parent, name, idx = _parse_base_name(var)
        !startswith(parent, prefix) && continue

        if !haskey(parents, parent)
            parents[parent] = Dict{Symbol, _VariableInfo}()
        end

        if !haskey(parents[parent], name)
            parents[parent][name] = _VariableInfo(
                name,
                isnothing(idx) ? [] : [idx],
                JuMP.is_binary(var),
                JuMP.is_integer(var),
                JuMP.is_fixed(var),
                JuMP.has_lower_bound(var) ? JuMP.lower_bound(var) : nothing,
                JuMP.has_upper_bound(var) ? JuMP.upper_bound(var) : nothing,
                JuMP.is_fixed(var) ? [JuMP.fix_value(var)] : [],
            )
        else
            if !isnothing(idx)
                push!(parents[parent][name].indices, idx)
            end
            if JuMP.is_fixed(var)
                push!(parents[parent][name].fix_values, JuMP.fix_value(var))
            end
        end
    end

    return parents
end

"""
    _parse_base_name(var::JuMP.VariableRef; base_index::Int64 = 0)

Parse the parent, the name, and the index from a `VariableRef`. `base_index` can be used to calculate the index as
offset based on a constraints specific time index.
"""
function _parse_base_name(var::JuMP.VariableRef; base_index::Int64=0)
    name = JuMP.name(var)

    if name == ""
        # This is an anonymous variable, which means its a slack variable created by `relax_with_penalty`.
        return "", Symbol("_z"), 0
    end

    if occursin("[", name)
        # This is a variable indexed by time.
        name, idx = split(name, "[")
        idx = (parse(Int64, idx[1:(end - 1)]) - base_index)
    else
        # This is a single variable (e.g. a Decision).
        idx = nothing
    end

    # The name is the right-most part, after the last `.`.
    parent, name = rsplit(name, "."; limit=2)

    return parent, Symbol(name), idx
end
