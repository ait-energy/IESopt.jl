@doc raw"""
    _connection_exp_pf_flow!(connection::Connection)

Construct the `JuMP.AffExpr` holding the PTDF based flow of this `Connection`.

This needs the global addon `Powerflow` with proper settings for `mode`, as well as properly configured power flow
parameters for this `Connection` (`pf_V`, `pf_I`, `pf_X`, ...).
"""
function _connection_exp_pf_flow!(connection::Connection)
    model = connection.model

    !haskey(_iesopt(model).input.addons, "Powerflow") && return
    !connection.is_pf_controlled[] && return

    if _iesopt(model).input.addons["Powerflow"].config["__settings__"].mode === :linear_angle
        connection.exp.pf_flow = [JuMP.AffExpr(0) for _ in _iesopt(model).model.T]
    end

    return nothing
end
