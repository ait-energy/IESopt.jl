module GlobalAddon_XOR

import IESopt
const JuMP = IESopt.JuMP

# We can use a global struct like this to keep a reference to the model (or other stuff):
struct _Settings
    model::JuMP.Model
    bigM::Float64
end

function initialize!(model::JuMP.Model, config::Dict{String, Any})
    # We can use standard Julia logging, but make sure to include the proper `[...]` prefix.
    @info "[GlobalAddon_XOR] Initializing"

    if !haskey(config, "bigM")
        @error "[GlobalAddon_XOR] Missing <bigM> parameter"
        return nothing
    end

    # Remember the model, as well as the big M.
    settings = _Settings(model, config["bigM"])

    return settings
end

# The following functions are called after they were called for all core components.

function setup!(model::JuMP.Model, settings::_Settings) end

function construct_expressions!(model::JuMP.Model, settings::_Settings) end

function construct_variables!(model::JuMP.Model, settings::_Settings)
    # We can access the model, as well as the set of all Snapshots like this:
    T = model.ext[:iesopt].model.T

    # Create the variable controlling the "XOR exchange" as binary.
    JuMP.@variable(model, exchange[t in T], Bin)
end

function construct_constraints!(model::JuMP.Model, settings::_Settings)
    T = model.ext[:iesopt].model.T

    # Prepare the chosen bigM.
    bigM = settings.bigM

    # Prepare the components that we want to access.
    buy_id = IESopt.component(model, "buy_id")
    sell_id = IESopt.component(model, "sell_id")

    # Prepare the exchange variable that we constructed earlier by accessing it directly from the JuMP model.
    exchange = model[:exchange]

    # It is allowed to either buy OR sell during each Snapshot.
    JuMP.@constraint(model, [t in T], buy_id.exp.value[t] <= exchange[t] * bigM)
    JuMP.@constraint(model, [t in T], sell_id.exp.value[t] <= (1.0 - exchange[t]) * bigM)
end

function construct_objective!(model::JuMP.Model, settings::_Settings) end

end
