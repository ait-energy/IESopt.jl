"""
    struct Snapshot
        name::_String
        id::_ID
        weight::_ScalarInput

        is_representative::Bool
        representative::_ID
    end

Represent a specific timestamp, that can be tied to timeseries values.

Each `Snapshot` expects a `name`, that can be used to hold a timestamp (as `String`; therefore supporting arbitrary
formats). The `weight` (default = 1.0) specifies the "probabilistic weight" of this `Snapshot` or the length of the
timeperiod that **begins** there (a `weight` of 2 can therefore represent a 2-hour-resolution; this also allows a
variable temporal resolution throughout the year/month/...).
"""
@kwdef struct Snapshot
    # mandatory
    name::_String
    id::_ID

    # optional
    weight::_ScalarInput = 1.0

    is_representative::Bool = true
    representative::_ID
end

function _parse_snapshots!(model::JuMP.Model)
    config = @config(model, optimization.snapshots)

    # Check for Snapshot aggregation.
    if !isnothing(config["aggregate"])
        @critical "Snapshot aggregation is deprecated in its current form"
        # @warn "Snapshot aggregation is an experimental feature, that does not work correctly with expressions (and maybe other stuff) - using it is not advised"

        # T_orig, T_factor = config.count, config.aggregate

        # if (T_orig ÷ T_factor) != (T_orig / T_factor)
        #     @critical "Cannot aggregate snapshots based on non exact divisor" T = T_orig div = T_factor
        # end

        # T = _ID(T_orig ÷ T_factor)
        # internal(model).model.snapshots = Dict{_ID, Snapshot}(
        #     t => Snapshot(; name="S$t <t$((t-1) * T_factor + 1)-t$(t * T_factor)>", id=t, weight=T_factor) for t in 1:T
        # )

        # # _iesopt_config(model)._perform_snapshot_aggregation = T_factor       # todo: config refactor
        # internal(model).model.T = 1:T

        # @info "Aggregated into $(length(internal(model).model.snapshots)) snapshots"
        # return nothing
    end

    # Set up `T`.
    internal(model).model.T = _ID.(1:(config["count"]::Int64))

    # Set up Snapshot names.
    if !isnothing(config["names"])
        column, file = String.(split(config["names"], "@"))
        # Make sure the parsed column is actually interpreted as Strings.
        names = string.(_getfromcsv(model, file, column))
    else
        names = ["t$t" for t in internal(model).model.T]
    end

    # Set up Snapshot weights.
    if !isnothing(config["weights"])
        if config["weights"] isa String
            column, file = String.(split(config["weights"], "@"))
            weights = _getfromcsv(model, file, column)
        elseif config["weights"] isa Number
            weights = ones(length(internal(model).model.T)) .* config["weights"]
        end
    else
        weights = ones(length(internal(model).model.T))
    end

    # Set up repesentatives and representation information.
    if !isnothing(config["representatives"])
        column, file = String.(split(config["representatives"], "@"))
        _repr = _getfromcsv(model, file, column)
        is_representative = ismissing.(_repr)

        repr_indices = [ismissing(_repr[t]) ? missing : findfirst(==(_repr[t]), names) for t in internal(model).model.T]
        if any(isnothing.(repr_indices))
            @critical "Missing repesentative detected; make sure that all names are actual Snapshot names"
        end

        representatives =
            [ismissing(_repr[t]) ? t : internal(model).model.T[repr_indices[t]] for t in internal(model).model.T]

        @debug "Activated representative Snapshots" n = sum(is_representative)
        _has_representative_snapshots(model) = true

        if any(weights[t] != weights[1] for t in internal(model).model.T[2:end])
            @critical "Representative Snapshots require equal `weights` for every Snapshot"
        end
    else
        is_representative = ones(Bool, length(internal(model).model.T))
        representatives = internal(model).model.T
    end

    internal(model).model.snapshots = Dict{_ID, Snapshot}(
        t => Snapshot(;
            name=names[t],
            id=t,
            weight=weights[t],
            is_representative=is_representative[t],
            representative=representatives[t],
        ) for t in internal(model).model.T
    )

    @debug "Parsed $(length(internal(model).model.snapshots)) snapshots"

    return nothing
end

_snapshot(model::JuMP.Model, t::_ID) = internal(model).model.snapshots[t]
_weight(model::JuMP.Model, t::_ID) = internal(model).model.snapshots[t].weight::Float64    # TODO: this should safety check with non-equal weights and representative snapshots

function _snapshot_aggregation!(model::JuMP.Model, data::Vector)
    # TODO: remove this (deprecated)
    config_agg = @config(model, optimization.snapshots.aggregate)

    if !isnothing(config_agg)
        if length(data) == 1
            return data
        end

        scale = config_agg
        return [sum(@view data[((t - 1) * scale + 1):(t * scale)]) / scale for t in internal(model).model.T]
    else
        return data
    end
end
