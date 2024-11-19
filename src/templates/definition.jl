"""
    CoreTemplate

A struct to represent an IESopt.jl "Core Template".
"""
@kwdef struct CoreTemplate
    model::JuMP.Model
    name::String
    path::String
    raw::String
    yaml::Dict{String, Any} = Dict{String, Any}()

    """A dictionary of functions that can be called by the template, options are `:validate`, `:prepare`, `:finalize`."""
    functions::Dict{Symbol, Function} = Dict{Symbol, Function}()

    """Type of this `CoreTemplate`: `:container` (if `"components"` exists), `:component` (if `"component"` exists)."""
    type::Ref{Symbol} = Ref(:none)

    _status::Ref{Symbol}
end
