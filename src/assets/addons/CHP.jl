module Addon_CHP

import IESopt

function build(comp_heat::IESopt._CoreComponent)
    model = comp_heat.model
    comp_power = IESopt.component(model, comp_heat.config["linked"])

    # Get all needed objects / parameters.
    T = model.ext[:iesopt].model.T
    cm = comp_heat.config["cm"]
    cv = comp_heat.config["cv"]

    # Extract P_max from the "power component"
    if comp_power.capacity_carrier.carrier.name != "electricity"
        @error "[Addon_CHP] Encountered wrong capacity carrier on power unit" carrier =
            comp_power.capacity_carrier.carrier.name
        return false
    end
    p_max = IESopt._get(comp_power.capacity)

    # Construct the backpressure constraint.
    # `c_m \cdot heat_t <= power_t`
    comp_heat.ext["constr_addon_CHP_backpressure"] =
        IESopt.@constraint(model, [t = T], cm * comp_heat.exp.out_heat[t] <= comp_power.exp.out_electricity[t])

    # Construct the isofuel constraint.
    # `power_t <= p_max - c_v \cdot heat_t`
    comp_heat.ext["constr_addon_CHP_isofuel"] =
        IESopt.@constraint(model, [t = T], comp_power.exp.out_electricity[t] <= p_max - cv * comp_heat.exp.out_heat[t])

    @info "[Addon_CHP] Finished constructing constraints"
    return true
end

end
