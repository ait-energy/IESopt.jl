@doc raw"""
    _node_var_pf_theta!(model::JuMP.Model, node::Node)

Construct the auxiliary phase angle variable for the `linear_angle` power flow algorithm.

This needs the global `Powerflow` addon, configured with `mode: linear_angle`, and constructs a variable `var_pf_theta`
for each `Snapshot`. If the `pf_slack` property of this `Node` is set to `true`, it does not add a variable but sets
`var_pf_theta[t] = 0` for each `Snapshot`.
```
"""
function _node_var_pf_theta!(node::Node)
    model = node.model

    !haskey(_iesopt(model).input.addons, "Powerflow") && return

    @error "Global addon based powerflow is deprecated until we finished the move to PowerModels.jl"
    return nothing

    if _has_representative_snapshots(model)
        @error "Representative Snapshots are currently not supported for models using Powerflow"
    end

    if _iesopt(model).input.addons["Powerflow"].config["__settings__"].mode === :linear_angle
        if node.pf_slack
            node.var.pf_theta = zeros(length(_iesopt(model).model.T))
        else
            node.var.pf_theta = @variable(
                model,
                [t = _iesopt(model).model.T],
                base_name = _base_name(node, "pf_theta"),
                container = Array
            )
        end
    end
end
