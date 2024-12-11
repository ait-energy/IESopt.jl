@doc raw"""
    _connection_exp_out!(connection::Connection)

The construction of a Connection's in/out expressions is directly done in `_connection_var_flow!(...)`, the function
that constructs the variable `flow`.
"""
function _connection_exp_out!(connection::Connection)
    connection.exp.out = collect(JuMP.AffExpr(0.0) for _ in get_T(connection.model))
    return nothing
end
