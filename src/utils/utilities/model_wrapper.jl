"""
    ModelWrapper

Wraps an IESopt.jl model to expose various easy access functions in `IESopt.Utilities`, and Core Template functions.

# Accessors:

- `timespan::Float64`: The total timespan of the model, in hours.
- `yearspan::Float64`: The total timespan of the model, in years, based on `1 year = 8760 hours`.
"""
struct ModelWrapper
    _iesopt_model::JuMP.Model
end

function Base.getproperty(mw::ModelWrapper, property::Symbol)
    _iesopt_model = getfield(mw, :_iesopt_model)

    if property == :model
        return _iesopt_model
    elseif property == :timespan
        return sum(s.weight for s in values(IESopt._iesopt_model(_iesopt_model).snapshots))
    elseif property == :yearspan
        return mw.timespan / 8760.0
    end

    @critical "Trying to access undefined property of (wrapped) model" property
end
