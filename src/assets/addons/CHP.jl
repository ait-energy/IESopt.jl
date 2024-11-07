module IESoptAddon_CHP

using IESopt
import JuMP

function initialize!(model::JuMP.Model, config::Dict)
    # All functions are expected to return `true` if everything went well.
    return true
end

# The following functions are called after they were called for all core components:
# - setup!
# - construct_expressions!
# - construct_variables!
# - construct_constraints!
# - construct_objective!
#
# If you do not need to modify the model during a specific step, you can just not implement the function.

function construct_constraints!(model::JuMP.Model, config::Dict)
    # NOTES:
    # - The tag "CHP" is set automatically, because it is the type of the component (which is a Virtual, instantiated
    #   from the respective template).
    # - Most of the time its best, to separate single steps of your model modifications into separate functions.
    #   This means, we are calling `link_units` for every CHP component in the model.

    return all(link_units.(get_components(model; tagged="CHP")))

    # The above is a shorthand for the following:
    #
    # ```julia
    # for chp in get_components(model, tagged="CHP")
    #     link_units(chp) || return false
    # end
    # return true    
    # ```

    # And a more versatile version of the above could look like:
    #
    # ```julia
    # success = true
    # success &= all(link_units.(get_components(model, tagged="CHP")))
    # success &= some_other_function(model)
    # success &= yet_another_function(model)
    # return success
    # ```
end

# ======================================================================================================================

function link_units(chp)
    # Every component knows about the whole model that it is part of. Doing the following is not necessary, but it
    # saves us some typing every time we want to access the model.
    model = chp.model

    # Get all needed objects / parameters (same reason as above).
    T = get_T(model)
    cm = chp.get("power_ratio")
    cv = chp.get("power_loss_ratio")

    # Extract P_max from the "power component".
    # Using `IESopt.access` is a safe way to access properties of CoreComponents, since this could actually be something
    # else than a plain "number" (e.g, a decision variable).
    p_max = access(chp.power.capacity)

    # Construct the backpressure constraint.
    # `c_m \cdot heat_t <= power_t`
    chp.con.backpressure = JuMP.@constraint(
        model,
        [t = T],
        cm * chp.heat.exp.out_heat[t] <= chp.power.exp.out_electricity[t],
        container = Array  # This is important, since JuMP does not "see" that our "T" allows for arrays.
    )

    # Construct the isofuel constraint.
    # `power_t <= p_max - c_v \cdot heat_t`
    chp.con.isofuel = JuMP.@constraint(
        model,
        [t = T],
        chp.power.exp.out_electricity[t] <= p_max - cv * chp.heat.exp.out_heat[t],
        container = Array  # This is important, since JuMP does not "see" that our "T" allows for arrays.
    )

    return true
end

end
