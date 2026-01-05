module IESoptAddon_CustomMath

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

function construct_variables!(model::JuMP.Model, config::Dict)
    T = get_T(model)

    node_input = get_component(model, "grid_gas")
    node_output = get_component(model, "grid_electricity")

    # we create here the breakpoints of the inputs
    # We did not set any limit on the upper bound, let's take 20 as end of BPs
    input_bp = 0.0:2:20.0
    eta(x, Pmax) = (x/Pmax)^1.5 + 0.1 
    ouptput_bp = eta.(input_bp, 25.0)
    N = length(input_bp)
    @assert N == length(ouptput_bp)
    
    JuMP.@variable(model, 0<=λ[1:N]<=1)
    
    JuMP.@variable(model, var_input[t in T], lower_bound=0.0)
    node_output.exp.generation = 1.1 .* JuMP.@variable(model, var_output[t in T], lower_bound=0.0, container=Array)

    JuMP.@constraints(
        model,
        var_input[t] == 
        [t in T],
        # NOTE: This could be a more complex mathematical expression, e.g., a piecewise interpolation.
        node_output.exp.generation[t] == 0.5 * model[:var_input][t]
    )

    for t in T
        JuMP.add_to_expression!(node_input.exp.injection[t], model[:var_input][t], -1.0)
        JuMP.add_to_expression!(node_output.exp.injection[t], node_output.exp.generation[t], 1.0)
    end

    return true
end

end