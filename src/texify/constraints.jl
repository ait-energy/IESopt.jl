function _compare_constraints(c1, c2)
    info1 = _parse_base_name(c1)
    info2 = _parse_base_name(c2)

    if info1[1] != info2[1]
        # The parents do not match, these are different constraints.
        return :distinct, info2[3]
    end

    if info1[2] != info2[2]
        # The base names do not match, these are different constraints.
        return :distinct, info2[3]
    end

    if isnothing(info1[3]) || isnothing(info2[3])
        # At least one of the constraints is not an indexed constraint (therefore a unique one).
        return :distinct, info2[3]
    end

    if typeof(JuMP.constraint_object(c1).set) != typeof(JuMP.constraint_object(c2).set)
        # The sets are different (e.g. `=` vs. `<=`), so the constraints are distinct.
        return :distinct, info2[3]
    end

    # Get the terms.
    terms1 = JuMP.linear_terms(JuMP.constraint_object(c1).func)
    terms2 = JuMP.linear_terms(JuMP.constraint_object(c2).func)

    if length(terms1) != length(terms2)
        # If the number of terms is not the same, the constraints are different.
        return :distinct, info2[3]
    end

    # Parse the coefficients, based on the extracted variable information.
    coeff1 = Dict(_parse_base_name(term[2]; base_index=(info1[3] - 1)) => term[1] for term in terms1)
    coeff2 = Dict(_parse_base_name(term[2]; base_index=(info2[3] - 1)) => term[1] for term in terms2)

    possible_return = :equal
    for (k, v) in coeff1
        if !haskey(coeff2, k)
            # Constraint 2 misses a term that constraint 1 has.
            return :distinct, info2[3]
        end

        if !(coeff2[k] ≈ v)
            # The coefficients are different.
            possible_return = :alike
        end
    end

    # Check if the right-hand sides match.
    if JuMP.normalized_rhs(c1) != JuMP.normalized_rhs(c2)
        possible_return = :alike
    end

    return possible_return, info2[3]        # info2[3] = "n2"
end

function _group_constraints(constraints)
    constr_groups = Dict{JuMP.ConstraintRef, NamedTuple}()
    for n in eachindex(constraints)
        elem = constraints[n]

        assigned = false
        for (repr, cg) in constr_groups
            similarity, n = _compare_constraints(repr, elem)

            if similarity === :equal
                push!(constr_groups[repr].constraints, elem)
                push!(constr_groups[repr].indices, n)
            elseif similarity === :alike
                push!(constr_groups[repr].constraints, elem)
                push!(constr_groups[repr].indices, n)
                constr_groups[repr] = (
                    constraints=constr_groups[repr].constraints,
                    similarity=:alike,
                    indices=constr_groups[repr].indices,
                )
            else
                continue
            end

            assigned = true
            break
        end

        if !assigned
            constr_groups[elem] = (constraints=[elem], similarity=:equal, indices=[n])
        end
    end

    return constr_groups
end

"""
    _parse_base_name(var::JuMP.ConstraintRef)

Parse the parent, the name, and the index from a `ConstraintRef`.
"""
function _parse_base_name(var::JuMP.ConstraintRef)
    name = JuMP.name(var)

    if occursin("[", name)
        # This is a constraint indexed by time.
        name, idx = split(name, "[")
        idx = parse(Int64, idx[1:(end - 1)])
    else
        # This is a single constraint.
        idx = nothing
    end

    # The name is the right-most part, after the last `.`.
    parent, name = rsplit(name, "."; limit=2)

    return parent, Symbol(name), idx
end
