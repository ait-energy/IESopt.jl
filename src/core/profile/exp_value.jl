@doc raw"""
    _profile_exp_value!(model::JuMP.Model, profile::Profile)

Cosntruct the `JuMP.AffExpr` that keeps the total value of this `Profile` for each `Snapshot`.

This is skipped if the `value` of this `Profile` is handled by an `Expression`. Otherwise it is intialized
based on `profile.value`.
"""
function _profile_exp_value!(profile::Profile)
    model = profile.model

    profile.exp.value = Vector{JuMP.AffExpr}()
    sizehint!(profile.exp.value, length(get_T(model)))
    for t in get_T(model)
        push!(profile.exp.value, JuMP.AffExpr(0.0))
    end

    return nothing
end
