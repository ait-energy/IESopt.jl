# A IESopt addon needs to adhere to the following general structure:
#
# ```
# module Addon_18
# 
# function build(comp::_CoreComponent)
#     ...
# end
# 
# end
# ```
#
# The function `build(comp)` will be called by the respective component, after everything is constructed (so basically
# after modifying the model's objective). You can always access the `JuMP.Model` using `comp.model`. You are free to add
# arbitrary code inside the module, even including other files. Attention: The addon's name MUST be unique!

module Addon_18

import ..IESopt

function build(comp::IESopt._CoreComponent)
    # Get the model.
    model = comp.model

    # Get the set of all snapshots.
    T = model.ext[:iesopt].model.T

    # Get the parameter that we want to use from the `config` attribute that we set in the `*.iesopt.yaml`.
    max_sum_energy = comp.config["max_sum_energy"]

    # We now add a new constraint, that keeps the amount of electricity generated below `max_sum_energy` for the
    # combination of two subsequent snapshots.
    # We can (this is optional!):
    #   - save the generated constraint into the `ext` dictionary of the component for later use
    #   - set a proper `base_name` utilizing the IESopt internal helper function
    model[Symbol("$(comp.name).constr_addon_18")] = IESopt.@constraint(
        model,
        [t = T[1:(end - 1)]],
        comp.exp.out_electricity[t] + comp.exp.out_electricity[t + 1] <= max_sum_energy,
        base_name = IESopt._base_name(comp, "constr_addon_18")
    )
    comp.ext["constr_addon_18"] = model[Symbol("$(comp.name).constr_addon_18")]

    # Important note: Normally you would (always!) use `my_constr_name[t = T[1:(end - 1)]]` inside the `@constraint`
    # macro. This ensures that you set a proper "internal descriptor" (`model[:my_constr_name]`), which ensures that we
    # properly pick it up during result extraction. Just setting the `base_name` is not enough! However, since this
    # constraint is constructed multiple times (to be exact: by two Units), you need to ensure its name is unique. This
    # is why we use `model[Symbol("$(comp.name).constr_addon_18")]` to manually add the constraint to the `JuMP` model.

    # This enables you to return `false` if something went wrong. If an error occurs, please also use
    # `@error "[MyAddonName] My error message" additional_parameter=42`
    # to provide addtional info before returning `false`. You can of course always also utilize the remaining Julia
    # logging functions. Please make sure to start all logging messages with `[MyAddonName]`.
    @info "[Addon_18] Finished constructing constraint."
    return true
end

end
