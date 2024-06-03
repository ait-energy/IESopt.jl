function _constr_group_equal_tostring(group; fixed_t=false)
    terms = JuMP.linear_terms(JuMP.constraint_object(group.constraints[1]).func)
    ct = group.indices[1]

    lhs = _expr_tostring([(_escape_variable(JuMP.name(term[2]), ct; fixed_t=fixed_t), term[1]) for term in terms])

    sign = (
        if JuMP.constraint_object(group.constraints[1]).set isa JuMP.MOI.EqualTo
            "= "
        elseif JuMP.constraint_object(group.constraints[1]).set isa JuMP.MOI.LessThan
            "\\leq "
        elseif JuMP.constraint_object(group.constraints[1]).set isa JuMP.MOI.GreaterThan
            "\\geq "
        else
            "[ERRSIGN] "
        end
    )

    rhs = "$(JuMP.normalized_rhs(group.constraints[1]))"

    return "\\begin{dmath}[style={\\eqmargin=0pt}]\n" * lhs * sign * rhs * "\n\\end{dmath}"
end

function _constr_group_alike_tostring(group)
    greeks = [
        "\\alpha",
        "\\beta",
        "\\gamma",
        "\\delta",
        "\\epsilon",
        "\\zeta",
        "\\eta",
        "\\theta",
        "\\iota",
        "\\kappa",
        "\\lambda",
    ]

    # Extract coefficients for each variable
    idx_first = min(group.indices...)
    idx_last = max(group.indices...)

    coeffs = Dict(
        group.indices[i] => Dict(
            (
                occursin("[", JuMP.name(term[2])) ? split(JuMP.name(term[2]), "[")[1] : JuMP.name(term[2]),
                occursin("[", JuMP.name(term[2])) ?
                parse(Int64, split(JuMP.name(term[2]), "[")[2][1:(end - 1)]) - group.indices[i] : 0,
            ) => term for term in JuMP.linear_terms(JuMP.constraint_object(group.constraints[i]).func)
        ) for i in eachindex(group.constraints)
    )

    expr = []
    greek_range = []
    for (k, v) in coeffs[idx_first]
        all_equal = false
        if v[1] ≈ coeffs[idx_last][k][1]
            # The first and last coefficient are the same. Check if all coefficients are the same.
            if allequal(elem[k][1] for elem in values(coeffs))
                all_equal = true
            end
        end

        if all_equal
            push!(expr, (_escape_variable(String(JuMP.name(v[2])), idx_first), v[1]))
        else
            push!(expr, (_escape_variable(String(JuMP.name(v[2])), idx_first), "$(greeks[length(greek_range) + 1])"))
            # todo: this gets triggered for decisions that are connected to an "availability_factor", but this is not printed correctly
            push!(greek_range, "[$(round(v[1], digits=4)),\\dots,$(round(coeffs[idx_last][k][1], digits=4))]")
        end
    end

    lhs = _expr_tostring(expr)

    sign = (
        if JuMP.constraint_object(group.constraints[1]).set isa JuMP.MOI.EqualTo
            "= "
        elseif JuMP.constraint_object(group.constraints[1]).set isa JuMP.MOI.LessThan
            "\\leq "
        elseif JuMP.constraint_object(group.constraints[1]).set isa JuMP.MOI.GreaterThan
            "\\geq "
        else
            "[ERRSIGN] "
        end
    )

    parameters = []

    rhs = round.(JuMP.normalized_rhs.(group.constraints), digits=4)
    if allequal(rhs)
        rhs = "$(JuMP.normalized_rhs(group.constraints[1]))"
    else
        push!(parameters, "\\vb{b} = [$(rhs[1]),\\dots,$(rhs[end])]")
        rhs = "\\vb{b}_t"
    end

    for i in eachindex(greek_range)
        push!(parameters, "$(greeks[i]) = $(greek_range[i])")
    end

    ret = "\\begin{dmath}[style={\\eqmargin=0pt}]\n" * lhs * sign * rhs * "\n\\end{dmath}"

    if length(parameters) > 0
        for param in parameters
            ret *= "\\begin{dmath*}[style={\\eqmargin=0pt}]\n" * param * "\n\\end{dmath*}"
        end
    end

    return ret
end

function _constr_group_tostring(group)
    ret = ""
    if group.similarity === :equal
        ret = _constr_group_equal_tostring(group)
    elseif group.similarity === :alike
        ret = _constr_group_alike_tostring(group)
    else
        @error " SOME ERR "
    end

    return ret
end

function _vars_tostring(variable_list, parent::String; digits=4)
    !haskey(variable_list, parent) && return ""

    str = ""
    for (k, var) in variable_list[parent]
        str *= "\\begin{dmath}[style={\\eqmargin=0pt}]\n{"
        escaped_var_name = "\\vb{" * replace(String(var.name), "_" => "\\_") * "}"
        indices = ""
        if length(var.indices) > 0
            escaped_var_name *= "_t"
            indices = "\\forall t \\in \\{$(min(var.indices...)), \\dots, $(max(var.indices...))\\}"
        end

        if !isnothing(var.upper_bound)
            # If it has an `upper_bound`, we look for a style of `x <= 10`.
            escaped_var_name *= " \\leq $(round(var.upper_bound; digits=digits)) "
            if !isnothing(var.lower_bound)
                # And if it has both, we extend to `0 <= x <= 10`.
                escaped_var_name = " $(round(var.lower_bound; digits=digits)) \\leq " * escaped_var_name
            end
        elseif !isnothing(var.lower_bound)
            # If no `upper_bound` exists, we present the `lower_bound` as `x >= 0`.
            escaped_var_name *= " \\geq $(round(var.lower_bound; digits=digits)) "
        end

        str *= escaped_var_name

        if var.is_binary || var.is_integer || var.is_fixed
            str *= "\\qquad ("
            str *= var.is_binary ? "\\in Bin," : ""
            str *= var.is_integer ? "\\in Int," : ""
            str *= var.is_fixed ? (length(var.fix_values) == 1 ? "some \\in Fix," : "\\in Fix,") : ""
            str = str[1:(end - 1)]
            str *= ")"
        end

        str *= "\\qquad $indices"
        str *= "}\n\\end{dmath}\n\n"
    end

    return str * "\n"
end

function _obj_tostring(model::JuMP.Model; digits=4)
    terms = JuMP.linear_terms(JuMP.objective_function(model))

    grouped_terms = Dict{String, Tuple{Vector{Int64}, Vector{Float64}}}()
    for term in terms
        bn = JuMP.name(term[2])

        if length(bn) == 0
            if !haskey(grouped_terms, "slack")
                grouped_terms["slack"] = ([0], [term[1]])
            else
                push!(grouped_terms["slack"][1], 0)
                push!(grouped_terms["slack"][2], term[1])
            end
        else
            if occursin('[', bn)
                _idx = findfirst("[", bn)[1]

                index = parse(Int64, bn[(_idx + 1):(end - 1)])
                bn = bn[1:(_idx - 1)]
            else
                # No time-index, therefore a Decision.
                index = 0
            end
            if !haskey(grouped_terms, bn)
                grouped_terms[bn] = ([index], [term[1]])
            else
                push!(grouped_terms[bn][1], index)
                push!(grouped_terms[bn][2], term[1])
            end
        end
    end

    cost_count = 1
    cost_values = ""
    obj_str = ""
    for (varname, info) in grouped_terms
        varname == "slack" && continue

        sign = (info[2][1] > 0) ? "+" : "-"
        if length(info[1]) == 1
            # Single value.
            obj_str *=
                "{$(sign) " * string(abs(round(info[2][1]; digits=4))) * "\\cdot" * _escape_variable(varname, 0) * "}"
        elseif length(info[1]) == length(_iesopt(model).model.T)
            # Full length.
            if allequal(info[2])
                obj_str *=
                    "{$(sign) " *
                    string(abs(round(info[2][1]; digits=4))) *
                    " \\cdot \\sum_{t \\in T}" *
                    _escape_variable("$(varname)[1]", 1) *
                    "}"
            else
                obj_str *=
                    "{+ " *
                    "\\sum_{t \\in T} \\vb{cost}_{$(cost_count),t} \\cdot" *
                    _escape_variable("$(varname)[1]", 1) *
                    "}"

                rng = (min(info[2]...), max(info[2]...))
                cost_values *= "\n\\begin{dmath}[style={\\eqmargin=0pt}]\n{\\vb{cost}_{$(cost_count),t} \\in [$(rng[1]),$(rng[2])] \\qquad \\forall t \\in T}\n\\end{dmath}"

                cost_count += 1
            end
        else
            # Partial length.
            if allequal(info[2])
                obj_str *=
                    "{$(sign) " *
                    string(abs(round(info[2][1]; digits=4))) *
                    "\\cdot \\sum_{t \\in S \\subset T}" *
                    _escape_variable("$(varname)[1]", 1) *
                    "}"
            else
                obj_str *=
                    "{+ " *
                    "\\sum_{t \\in S \\subset T} \\vb{cost}_{$(cost_count),t} \\cdot" *
                    _escape_variable("$(varname)[1]", 1) *
                    "}"

                rng = (min(info[2]...), max(info[2]...))
                cost_values *= "\n\\begin{dmath}[style={\\eqmargin=0pt}]\n{\\vb{cost}_{$(cost_count),t} \\in [$(rng[1]),$(rng[2])] \\qquad \\forall t \\in S \\subset T}\n\\end{dmath}"

                cost_count += 1
            end
        end
        obj_str *= "\\\\"
    end

    if haskey(grouped_terms, "slack")
        if allequal(grouped_terms["slack"][2])
            penalty = grouped_terms["slack"][2][1]
            obj_str *= "{+ $(penalty) \\cdot \\sum_{i \\in I, t \\in T} \\vb{slack}_{i,t}}\\\\"
        else
            obj_str *= "{+ \\sum_{i \\in I, t \\in T} \\vb{cost}_{slack,i} \\cdot \\vb{slack}_{i,t}}\\\\"

            rng = (min(grouped_terms["slack"][2]...), max(grouped_terms["slack"][2]...))
            cost_values *= "\n\\begin{dmath}[style={\\eqmargin=0pt}]\n{\\vb{cost}_{slack} = [$(rng[1]),\\dots,$(rng[2])]}\n\\end{dmath}"
        end
    end

    obj_str = "{" * obj_str[3:(end - 2)]

    return "\\begin{dmath}[style={\\eqmargin=0pt}]\n\\vb{\\min}\\\\" * obj_str * "\n\\end{dmath}" * cost_values
end

function _int2timeidx(t::Int64)
    if t == 0
        return "t"
    elseif t > 0
        return "{t+$t}"
    else
        return "{t-$(abs(t))}"
    end
end

function _escape_variable(str::String, base_t; fixed_t=false)
    index = ""
    if occursin("[", str)
        str, index = split(str, "[")
        index = index[1:(end - 1)]
    end
    str = replace(str, "_" => "\\_")

    if length(str) == 0
        return "\\vb{slack}_{?}"
    end

    if occursin('.', str)
        str, var = rsplit(str, "."; limit=2)
    else
        var = "?"
    end

    if index == ""
        return "\\vb{$str}_{\\vb{$var}}"
    end

    if fixed_t
        return "\\vb{$str}_{\\vb{$var}_{$index}}"
    end

    index = _int2timeidx(parse(Int64, index) - base_t)
    return "\\vb{$str}_{\\vb{$var}_{$index}}"
end

function _expr_tostring(expr::Vector; digits=4)
    ret = ""

    for i in eachindex(expr)
        var = expr[i][1]
        coeff = expr[i][2]

        if coeff isa Number
            if coeff ≈ 1.0
                coeff = "+ {"
            elseif coeff ≈ -1.0
                coeff = "- {"
            else
                if coeff > 0
                    coeff = "+ {$(round(abs(coeff); digits=digits))\\cdot "
                else
                    coeff = "- {$(round(abs(coeff); digits=digits))\\cdot "
                end
            end
        else
            coeff = "+ {$coeff\\cdot "
        end

        ret *= "$(coeff)$(var)} "
    end

    if ret[1:2] == "+ "
        return ret[3:end]
    end
    if ret[1:2] == "- "
        return "{-~" * ret[4:end]
    end

    return ret
end

# _test_epxr = [("x_1", 1.0), ("x_2", -1.0), ("y", "α")]
# print(_expr_tostring(_test_epxr))
