@doc raw"""
    _node_con_last_state!(node::Node)

Add the constraint for the `node`'s state at the first Snapshot to `node.model`, if
`node.has_state == true` and `node.initial_state` is set.
"""
function _node_con_first_state!(node::Node)
    node.has_state || return nothing
    _isempty(node.state_initial) && return nothing
    model = node.model
    node.con.first_state = @constraint(
        model,
        node.var.state[1] == node.state_initial.value,
        base_name = make_base_name(node, "first_state")
    )
    return nothing
end
