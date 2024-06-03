"""
    ModelWrapper

Wraps an IESopt.jl model to expose various easy access functions in `IESopt.Utilities`, and Core Template functions.

# Accessors:

- `timespan::Float64`: The total timespan of the model, in hours.
- `yearspan::Float64`: The total timespan of the model, in years, based on `1 year = 8760 hours`.
"""
struct ModelWrapper
    model::JuMP.Model
end

function Base.getproperty(mw::ModelWrapper, property::Symbol)
    if property == :model
        return getfield(mw, :model)
    elseif property == :timespan
        return sum(s.weight for s in values(IESopt._iesopt_model(mw.model).snapshots))
    elseif property == :yearspan
        return mw.timespan / 8760.0
    end

    @critical "Trying to access undefined property of (wrapped) model" property
end
