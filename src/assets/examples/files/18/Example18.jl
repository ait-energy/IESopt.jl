module IESoptAddon_Example18

using IESopt
import JuMP

function initialize!(model::JuMP.Model, config::Dict)
    if !haskey(config, "active")
        # We can use standard Julia logging, but make sure to include the proper `[...]` prefix.
        @error "[IESoptAddon_Example18] Detected missing parameters"

        # All functions can return `false` to indicate that something went wrong.
        return false
    end

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
    # This `config`, is the content of the addon dictionary, set in the top-level config using:
    # ```yaml
    # addons:
    #   Example18: {active: true}
    # ```
    if !config["active"]
        return true
    end
    # Compared to that, we'll use `unit.config` later, which is the `config` attribute of the individual Unit.

    # Get the set of all snapshots.
    T = get_T(model)

    # Find all Units that we want to modify.
    for unit in get_components(model; tagged=["ModifyMe"])
        # Get the parameter that we want to use from the `config` attribute that we set in the `*.iesopt.yaml`.
        max_sum_energy = unit.config["max_sum_energy"]

        # We now add a new constraint, that keeps the amount of electricity generated below `max_sum_energy` for the
        # combination of two subsequent snapshots.
        unit.con.example18 = JuMP.@constraint(
            model,
            [t = T[1:(end - 1)]],
            unit.exp.out_electricity[t] + unit.exp.out_electricity[t + 1] <= max_sum_energy,
            base_name = make_base_name(unit, "con_addon_18"),
            container = Array,
        )

        # NOTES:
        # - We use `T[1:(end - 1)]` to ensure that we do not run out of bounds.
        # - We create a proper "readable" name for the constraint using `make_base_name(...)`.
        # - We use `container = Array` to ensure that JuMP knows that `T` is an "efficient array".
        # - We store the constraint in the `unit` object, so that we can access it later on.

        # Accessing the constraint is now possible using `unit.con.example18`, e.g.:
        # ```julia
        # units = get_components(model, tagged=["ModifyMe"])
        # JuMP.shadow_price.(units[1].con.example18)
        # ```
    end

    # This enables you to return `false` if something went wrong. If an error occurs, please also use
    # `@error "[MyAddonName] My error message" additional_parameter=42`
    # to provide addtional info before returning `false`. You can of course always also utilize the remaining Julia
    # logging functions. Please make sure to start all logging messages with `[MyAddonName]`.

    @info "[IESoptAddon_Example18] Finished constructing constraint."

    return true
end

end
