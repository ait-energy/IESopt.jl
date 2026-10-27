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

    # we create here the breakpoints of the inputs let's take 20  BPs
    Pmax = 20.
    a,b,c = [0.7012, 0.0662, 0.3671 ] # coeffs for efficiency

    function eta(P::Float64)
        prel = P/Pmax
        return 0.1 + c *( prel^a / (prel^a + b^a)  )
    end
    function power_input(P::Float64)
        return P/eta(P)
    end

    output_bp = collect(range(0.0, Pmax, length=10))   # electricity out
    input_bp  = power_input.(output_bp)               # gas in
    N = length(input_bp)
    ## ======================
    
    @assert N == length(output_bp)
    
    JuMP.@variable(model, var_input[t in T], lower_bound=0.0)
    JuMP.@variable(model, var_output[t in T] >= 0.0, container=Array)

    node_output.exp.generation = [1.0 * var_output[t] for t in T] ## IESopt exp fields want AffExpr / Vector{AffExpr}, so make it explicitly affine

    JuMP.@variable(model, 0<= λ[t in T, i in 1:N] <= 1.0) # SOS2 weights PER snapshot

    JuMP.@constraints( model, begin
        [t in T], var_input[t]  == sum(λ[t,i] * input_bp[i]   for i in 1:N)
        [t in T], var_output[t] == sum(λ[t,i] * output_bp[i]  for i in 1:N)
        [t in T], sum(λ[t,i] for i in 1:N) == 1
    end)
    JuMP.@constraint( model,[t in T], λ[t, 1:N] in JuMP.SOS2() )

    for t in T
        JuMP.add_to_expression!(node_input.exp.injection[t], model[:var_input][t], -1.0)
        JuMP.add_to_expression!(node_output.exp.injection[t], node_output.exp.generation[t], 1.0)
    end

    return true
end

end