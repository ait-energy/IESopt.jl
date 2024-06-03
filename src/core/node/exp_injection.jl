@doc raw"""
    _node_exp_injection!(node::Node)

Add an empty (`JuMP.AffExpr(0)`) expression to the `node` that keeps track of feed-in and withdrawal of energy.

This constructs the expression ``\text{injection}_t, \forall t \in T`` that is utilized in
`node.con.nodalbalance`. Core components (`Connection`s, `Profile`s, and `Unit`s) that feed energy into
this node add to it, all others subtract from it. A stateless node forces this nodal balance to always equal `0` which
essentially describes "generation = demand".
"""
function _node_exp_injection!(node::Node)
    model = node.model

    node.exp.injection = collect(JuMP.AffExpr(0) for _ in _iesopt(model).model.T)

    if !isnothing(node.etdf_group)
        # Add this node's "net positions" (= it's injections) to the overall ETDF group.
        push!(_iesopt(model).aux.etdf.groups[node.etdf_group], node.id)
    end
end
