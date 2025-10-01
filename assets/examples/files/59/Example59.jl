module IESoptAddon_Example59

using IESopt
import JuMP

function initialize!(model::JuMP.Model, config::Dict)
    return true
end

function construct_constraints!(model::JuMP.Model, config::Dict)
    # Get the consumption grid connection.
    conn = get_component(model, "grid_connection_buy")

    # Apply the monthly varying power consumption tariffs as "upper bounds".
    for m in 1:12
        decision = get_component(model, "grid_tariff_power_consumption_$m")

        # Note: For more complex "months" (e.g., accounting for February, leap years, etc.), this could just be
        # loaded from the `config` dict (set inside the YAML), or based on a manual list here.
        t0 = (m-1) * 728

        JuMP.@constraint(
            model,
            [t = 1:728],
            conn.var.flow[t + t0] <= decision.var.value,
            base_name = "grid_tariff_month_$m",
        )
    end

    return true
end

end
