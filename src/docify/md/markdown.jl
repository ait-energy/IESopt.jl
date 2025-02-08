function _docify_to_markdown(model::JuMP.Model, filename::String)
    components = internal(model).model.components

    open(filename, "w") do io
        println(io, "# Components\n")

        for (name, component) in components
            println(io, "## `$(name)`\n")
            println(io, "### Variables\n")
            for v in _describe_variables(component)
                println(io, v)
            end
            println(io, "### Constraints\n")
            for c in _describe_constraints(component)
                println(io, c)
            end
            println(io, "### Expressions\n")
            for e in _describe_expressions(component)
                println(io, e)
            end
            println(io, "### Objectives\n")
            for o in _describe_objectives(component)
                println(io, o)
            end
        end
    end
end

function _escape(s)
    return replace(string(s), "_" => "\\_")
end

function _limit_naive(item)
    str = string(item)

    if length(str) > 100
        return str[1:45] * " ... " * str[(end - 45):end]
    else
        return str
    end
end

function _describe_variables(component)
    variables = []
    for k in keys(component.var)
        v = getproperty(component.var, k)
        T = length(v)
        str = "#### `$(k)`\n\n"
        str *= "\$\$\n"
        str *= "\\textbf{$(_escape(k))}_t, \\quad \\forall t \\in \\{1, \\dots, $T\\}"
        str *= "\n\$\$\n"
        push!(variables, str)
    end
    return variables
end

function _describe_constraints(component)
    constraints = []
    for k in keys(component.con)
        description = _describe_constraint(getproperty(component.con, k))

        if isa(description, String)
            str = "#### `$(k)`\n\n"
            str *= _limit_naive(description)
        else
            for entry in description
                str = "#### `$(k)`\n\n"
                str *= "\$\$\n"
                str *= _constraint_to_string(entry)
                str *= ", \\quad \\forall t \\in \\{$(entry.t_from), \\dots, $(entry.t_to)\\}"
                str *= "\n\$\$\n"
            end
        end
        push!(constraints, str)
    end
    return constraints
end

function _describe_expressions(component)
    expressions = []
    for k in keys(component.exp)
        description = _describe_expression(getproperty(component.exp, k))

        if isa(description, String)
            str = "#### `$(k)`\n\n"
            str *= _limit_naive(description)
        else
            for entry in description
                str = "#### `$(k)`\n\n"
                str *= "\$\$\n"
                str *= _expression_to_string(entry)
                str *= ", \\quad \\forall t \\in \\{$(entry.t_from), \\dots, $(entry.t_to)\\}"
                str *= "\n\$\$\n"
            end
        end
        push!(expressions, str)
    end
    return expressions
end

function _describe_objectives(component)
    objectives = []
    for k in keys(component.obj)
        o = getproperty(component.obj, k)
        str = "#### `$(k)`\n\n"
        str *= _limit_naive(o)
        push!(objectives, str)
    end
    return objectives
end

function _make_var(term)
    return "\\textbf{$(_escape(term[2]))}^{(\\text{$(_escape(term[1]))})}"
end

function _make_t(delta)
    if delta == 0
        return "{t}"
    elseif delta > 0
        return "{t+$(delta)}"
    else
        return "{t-$(abs(delta))}"
    end
end

function _expression_to_string(e)
    str = ""
    if e.shape == :identical
        str *= join(["($(t[4])) \\cdot $(_make_var(t))_$(_make_t(t[3]))" for t in e.repr.terms], " + ")
        str *= " + ($(e.repr.constant))"
    elseif e.shape == :alike
        str *= join(
            ["\\alpha^{($(i))}_{t} \\cdot $(_make_var(t))_$(_make_t(t[3]))" for (i, t) in enumerate(e.repr.terms)],
            " + ",
        )
        str *= " + \\beta_t"
    end
    return replace(str, "+ (-" => "- (")
end

function _constraint_to_string(c)
    str = ""
    if c.shape == :identical
        str *= join(["($(t[4])) \\cdot $(_make_var(t))_$(_make_t(t[3]))" for t in c.repr.lhs], " + ")
        str *= " $(c.repr.sign) $(c.repr.rhs)"
    elseif c.shape == :alike
        str *= join(
            ["\\alpha^{($(i))}_{t} \\cdot $(_make_var(t))_$(_make_t(t[3]))" for (i, t) in enumerate(c.repr.lhs)],
            " + ",
        )
        str *= " $(c.repr.sign) \\beta_t"
    end
    return replace(str, "+ (-" => "- (")
end

function _describe_constraint(c)
    if !isa(c, Vector)
        return JuMP.constraint_string(MIME("text/latex"), c; in_math_mode=true)
    end

    T = length(c)

    # Standardize each constraint.
    std_con = []
    for t in eachindex(c)
        cobj = JuMP.constraint_object(c[t])

        rhs = JuMP.MOI.constant(cobj.set)
        sign = split(JuMP.MOIU._to_string(MIME("text/latex"), cobj.set), " ")[1]

        std_terms = []
        for (var, coeff) in cobj.func.terms
            # Get name of variable.
            name = JuMP.name(var)

            # Check if it is indexed.
            index = -1
            if occursin(r"\[\d+\]", name)
                index = parse(Int, match(r"\[(\d+)\]", name).captures[1])
                name = replace(name, r"\[\d+\]" => "")
            end

            # Extract the referenced component and variable.
            comp_ref, var_ref = rsplit(name, "."; limit=2)

            # Create the standard representation.
            if index > 0
                push!(std_terms, (comp_ref, var_ref, index - t, coeff))
            else
                push!(std_terms, (comp_ref, var_ref, nothing, coeff))
            end
        end

        sort!(std_terms; by=t -> (t[1], t[2]))
        push!(std_con, (lhs=std_terms, sign=sign, rhs=rhs))
    end

    # TODO: constraints could be "alike" in the RHS and "identical" in the LHS, which shoould be better tracked
    #       Example: RES availability

    # Find out how to group the constraints (:identical, :alike, :distinct).
    groups = []
    curr = (t_from=1, shape=:identical, repr=std_con[1])
    for t in eachindex(c)[2:end]
        fit = curr.shape

        # Compare sign.
        if curr.repr.sign != std_con[t].sign
            fit = :distinct
        end

        # Compare right-hand side.
        if (fit == :identical) && (curr.repr.rhs != std_con[t].rhs)
            fit = :alike
        end

        # Compare left-hand side.
        if (fit != :distinct)
            if length(curr.repr.lhs) != length(std_con[t].lhs)
                fit = :distinct
            else
                for i in eachindex(curr.repr.lhs)
                    # Component reference, variable reference, index delta.
                    for j in 1:3
                        if curr.repr.lhs[i][j] != std_con[t].lhs[i][j]
                            fit = :distinct
                            break
                        end
                    end
                    fit == :distinct && break

                    # Coefficient.
                    if curr.repr.lhs[i][4] != std_con[t].lhs[i][4]
                        fit = :alike
                    end
                end
            end
        end

        if fit == :distinct
            push!(groups, (t_from=1, t_to=t - 1, shape=curr.shape, repr=curr.repr))
            curr = (t_from=t, shape=:identical, repr=std_con[t])
        elseif fit == :alike
            curr = (t_from=curr.t_from, shape=:alike, repr=curr.repr)
        end
    end
    push!(groups, (t_from=1, t_to=T, shape=curr.shape, repr=curr.repr))

    # Describe the constraints using its groups.
    return groups
end

function _describe_expression(e)
    if !isa(e, Vector)
        return JuMP.function_string(MIME("text/latex"), e)
    end

    T = length(e)

    # Standardize each expression.
    std_exp = []
    for t in eachindex(e)
        constant = e[t].constant

        std_terms = []
        for (var, coeff) in e[t].terms
            # Get name of variable.
            name = JuMP.name(var)

            # Check if it is indexed.
            index = -1
            if occursin(r"\[\d+\]", name)
                index = parse(Int, match(r"\[(\d+)\]", name).captures[1])
                name = replace(name, r"\[\d+\]" => "")
            end

            # Extract the referenced component and variable.
            comp_ref, var_ref = rsplit(name, "."; limit=2)

            # Create the standard representation.
            if index > 0
                push!(std_terms, (comp_ref, var_ref, index - t, coeff))
            else
                push!(std_terms, (comp_ref, var_ref, nothing, coeff))
            end
        end

        sort!(std_terms; by=t -> (t[1], t[2]))
        push!(std_exp, (terms=std_terms, constant=constant))
    end

    # Find out how to group the expressions (:identical, :alike, :distinct).
    groups = []
    curr = (t_from=1, shape=:identical, repr=std_exp[1])
    for t in eachindex(e)[2:end]
        fit = curr.shape

        # Compare constant.
        if curr.repr.constant != std_exp[t].constant
            fit = :alike
        end

        # Compare terms.
        if (fit != :distinct)
            if length(curr.repr.terms) != length(std_exp[t].terms)
                fit = :distinct
            else
                for i in eachindex(curr.repr.terms)
                    # Component reference, variable reference, index delta.
                    for j in 1:3
                        if curr.repr.terms[i][j] != std_exp[t].terms[i][j]
                            fit = :distinct
                            break
                        end
                    end
                    fit == :distinct && break

                    # Coefficient.
                    if curr.repr.terms[i][4] != std_exp[t].terms[i][4]
                        fit = :alike
                    end
                end
            end
        end

        if fit == :distinct
            push!(groups, (t_from=1, t_to=t - 1, shape=curr.shape, repr=curr.repr))
            curr = (t_from=t, shape=:identical, repr=std_exp[t])
        elseif fit == :alike
            curr = (t_from=curr.t_from, shape=:alike, repr=curr.repr)
        end
    end
    push!(groups, (t_from=1, t_to=T, shape=curr.shape, repr=curr.repr))

    # Describe the constraints using its groups.
    return groups
end
