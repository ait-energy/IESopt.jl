"""
    struct Carrier
        name::String
        unit::Union{String, Nothing}
    end

Represents a single (energy) carrier with a given `name`.

This is mostly used to represent various commodities that (easily) represent some form of energy (e.g. gas, water, ...),
but also enables modelling commodities that are not (treated as) representing some type of energy (e.g. CO2). Specify
`unit` to bind that carrier to an (arbitrary) unit that allows easier plotting and result analysis.
"""
@kwdef struct Carrier
    # mandatory
    name::String

    # optional
    unit::Union{String, Nothing} = nothing
    color::Union{String, Nothing} = nothing
end

@recompile_invalidations begin
    Base.hash(carrier::Carrier) = hash(carrier.name)
end

"""
    _parse_carriers(carriers::Dict{String, Any})

Correctly parses a dictionary of carriers (obtained from reading model.yaml) into a dictionary that maps the carrier
name onto the `Carrier`.
"""
function _parse_carriers!(model::JuMP.Model, carriers::Dict{String, Any})
    _iesopt(model).model.carriers = Dict{String, Carrier}(
        k => Carrier(; name=k, Dict(Symbol(prop) => val for (prop, val) in props)...) for (k, props) in carriers
    )

    return nothing
end

# function _parse_carriers!(model::JuMP.Model, ::Nothing, ::_CSVModel)
#     df = _iesopt(model).input.files["carriers"]
#     _iesopt(model).model.carriers = Dict{String, Carrier}(
#         row["name"] => Carrier(; Dict(Symbol(k) => v for (k, v) in zip(names(row), row) if !ismissing(v))...) for row in DataFrames.eachrow(df)
#     )
# end

@recompile_invalidations begin
    Base.string(carrier::Carrier) = carrier.name
end
