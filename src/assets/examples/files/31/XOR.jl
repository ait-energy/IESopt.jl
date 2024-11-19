module IESoptAddon_ExampleXOR

using IESopt
import JuMP

function initialize!(model::JuMP.Model, config::Dict)
    # We can use standard Julia logging, but make sure to include the proper `[...]` prefix.
    @info "[IESoptAddon_ExampleXOR] Initializing"

    if !haskey(config, "bigM")
        @error "[IESoptAddon_ExampleXOR] Missing <bigM> parameter"
        return false
    end

    return true
end

function construct_variables!(model::JuMP.Model, config::Dict)
    # Create the variable controlling the "XOR exchange" as binary.
    JuMP.@variable(model, exchange[t in get_T(model)], Bin)

    # As you can see we are not attaching it to any component. This may be bad, but since it's  a JuMP model we can
    # basically do whatever JuMP supports. Here, it actually registers `model[:exchange]` as a variable in the JuMP
    # model.

    return true
end

function construct_constraints!(model::JuMP.Model, config::Dict)
    T = get_T(model)

    # Prepare the chosen bigM.
    bigM = config["bigM"]

    # Prepare the components that we want to access.
    buy_id = get_component(model, "buy_id")
    sell_id = get_component(model, "sell_id")

    # Prepare the exchange variable that we constructed earlier by accessing it directly from the JuMP model.
    exchange = model[:exchange]

    # It is allowed to either buy OR sell during each Snapshot.
    JuMP.@constraint(model, [t in T], buy_id.exp.value[t] <= exchange[t] * bigM)
    JuMP.@constraint(model, [t in T], sell_id.exp.value[t] <= (1.0 - exchange[t]) * bigM)

    return true
end

end
