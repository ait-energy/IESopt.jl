@doc raw"""
    _node_var_state!(model::JuMP.Model, node::Node)

Add the variable representing the state of this `node` to the `model`, if `node.has_state == true`. This can be accessed
via `node.var.state[t]`.

Additionally, if the state's initial value is specified via `state_initial` the following gets added:
```math
\text{state}_1 = \text{state}_{initial}
```
"""
function _node_var_state!(node::Node)
    if !node.has_state
        return nothing
    end

    model = node.model

    node.var.state = @variable(model, [t = get_T(model)], base_name = make_base_name(node, "state"), container = Array)

    return nothing
end
