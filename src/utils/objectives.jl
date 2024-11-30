
"""
    register_objective!(model::JuMP.Model, objective::String)

Register a new objective in the model, which can for dynamically creating objectives, e.g., in addons.

# Arguments

- `model::JuMP.Model`: The model to register the objective in.
- `objective::String`: The name of the objective to register.

# Example

```julia
register_objective!(model, "my_obj")
```

which is equivalent to:

```yaml
config:
  optimization:
    objectives:
      my_obj: []
```
"""
function register_objective!(model::JuMP.Model, objective::String)
    internal(model).model.objectives[objective] =
        (terms=Set{Union{JuMP.AffExpr, JuMP.VariableRef}}(), expr=JuMP.AffExpr(0.0), constants=Vector{Float64}())
    internal(model).aux._obj_terms[objective] = String[]

    return nothing
end

"""
    add_term_to_objective!(model::JuMP.Model, objective::String, term::Union{JuMP.AffExpr, JuMP.VariableRef})

Add a term to an objective in the model, which can be used for dynamically creating objectives, e.g., in addons.

The default objective (that always exists) is called "total_cost". Other objectives can be dynamically registered using
`register_objective!`, or they can be added based on the YAML configuration.

# Arguments

- `model::JuMP.Model`: The model to add the term to.
- `objective::String`: The name of the objective to add the term to.
- `term::Union{JuMP.AffExpr, JuMP.VariableRef}`: The term to add to the objective.

# Example

```julia
add_term_to_objective!(model, "my_obj", 2 * x)
```
"""
function add_term_to_objective!(model::JuMP.Model, objective::String, term::Union{JuMP.AffExpr, JuMP.VariableRef})
    push!(internal(model).model.objectives[objective].terms, term)
    return nothing
end
