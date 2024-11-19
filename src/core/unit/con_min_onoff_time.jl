@doc raw"""
    _unit_con_min_onoff_time!(model::JuMP.Model, unit::Unit)

Add the constraints modeling min on- or off-time of a `Unit` to the `model`.

This constructs the constraints
```math
\begin{align}
    & \sum_{t' = t}^{t + \text{min\_on\_time}} ison_{t'} >= \text{min\_on\_time} \cdot (ison_t - ison_{t-1}) \qquad \forall t \in T \\
    & \sum_{t' = t}^{t + \text{min\_off\_time}} (1 - ison_{t'}) >= \text{min\_off\_time} \cdot (ison_{t-1} - ison_t) \qquad \forall t \in T
\end{align}
```

respecting `on_time_before` and `off_time_before`, and `is_on_before`. See the code for more details.

!!! info "Aggregated units"
    This is currently not fully adapted to account for `Unit`s with `unit_count > 1`.
"""
function _unit_con_min_onoff_time!(unit::Unit)
    if unit.unit_commitment === :off
        return nothing
    end

    model = unit.model
    T = get_T(model)

    # Pre-calculate the cumulative sum of all Snapshots.
    duration_sum = cumsum(_weight(model, t) for t in T)

    if !isnothing(unit.min_on_time)
        # Calculate set of Snapshots for each `t` that belong to the time set.
        T_min_on = Vector{NamedTuple{(:t_end, :force, :max_dur), Tuple{_ID, Bool, Int64}}}()
        sizehint!(T_min_on, length(T))
        for t in T
            if (unit.is_on_before != 0) && (duration_sum[t] <= (unit.min_on_time - unit.on_time_before))
                push!(T_min_on, (t_end=0, force=true, max_dur=0))
                continue
            end

            # Calculate the "time" until which we need to check.
            t_end = duration_sum[t] + (unit.min_on_time - _weight(model, t))
            # Check all "timings" if we reached the previously calculated time, so that we can "cut off".
            cutoff = duration_sum[t:end] .>= t_end

            max_dur = unit.min_on_time
            if !any(cutoff)
                # We are overlapping with the end of the horizon.
                max_dur = duration_sum[end] - duration_sum[t] + _weight(model, t)
                t_end = length(T)
            else
                # Get the first Snapshot that fulfils the duration.
                t_end = argmax(cutoff) + (t - 1)

                # Check if that match is exact.
                if (duration_sum[t_end] - duration_sum[t] + _weight(model, t)) != unit.min_on_time
                    @warn "Unit minimum up time not matching with differing Snapshot weights" unit = unit.name
                end
            end

            push!(T_min_on, (t_end=t_end, force=false, max_dur=max_dur))
        end

        # Construct the constraints.
        unit.con.min_on_time = Vector{JuMP.ConstraintRef}()
        sizehint!(unit.con.min_on_time, length(T))
        for t in T
            if T_min_on[t].force
                push!(
                    unit.con.min_on_time,
                    @constraint(model, unit.var.ison[t] == 1, base_name = make_base_name(unit, "min_on_time", t))
                )
            else
                prev = (t == 1) ? Int64(unit.is_on_before) : unit.var.ison[t - 1]
                push!(
                    unit.con.min_on_time,
                    @constraint(
                        model,
                        sum(unit.var.ison[_t] for _t in t:(T_min_on[t].t_end)) >=
                        T_min_on[t].max_dur * (unit.var.ison[t] - prev),
                        base_name = make_base_name(unit, "min_on_time", t)
                    )
                )
            end
        end
    end

    if !isnothing(unit.min_off_time)
        # Calculate set of Snapshots for each `t` that belong to the time set.
        T_min_off = Vector{NamedTuple{(:t_end, :force, :max_dur), Tuple{_ID, Bool, Int64}}}()
        sizehint!(T_min_off, length(T))
        for t in T
            if (unit.is_on_before == 0) && (duration_sum[t] <= (unit.min_off_time - unit.off_time_before))
                push!(T_min_off, (t_end=0, force=true, max_dur=0))
                continue
            end

            # Calculate the "time" until which we need to check.
            t_end = duration_sum[t] + (unit.min_off_time - _weight(model, t))
            # Check all "timings" if we reached the previously calculated time, so that we can "cut off".
            cutoff = duration_sum[t:end] .>= t_end

            max_dur = unit.min_off_time
            if !any(cutoff)
                # We are overlapping with the end of the horizon.
                max_dur = duration_sum[end] - duration_sum[t] + _weight(model, t)
                t_end = length(T)
            else
                # Get the first Snapshot that fulfils the duration.
                t_end = argmax(cutoff) + (t - 1)

                # Check if that match is exact.
                if (duration_sum[t_end] - duration_sum[t] + _weight(model, t)) != unit.min_off_time
                    @warn "Unit minimum down time not matching with differing Snapshot weights" unit = unit.name
                end
            end

            push!(T_min_off, (t_end=t_end, force=false, max_dur=max_dur))
        end

        # Construct the constraints.
        unit.con.min_off_time = Vector{JuMP.ConstraintRef}()
        sizehint!(unit.con.min_off_time, length(T))
        for t in T
            if T_min_off[t].force
                push!(
                    unit.con.min_off_time,
                    @constraint(model, unit.var.ison[t] == 0, base_name = make_base_name(unit, "min_off_time", t))
                )
            else
                prev = (t == 1) ? Int64(unit.is_on_before) : unit.var.ison[t - 1]
                push!(
                    unit.con.min_off_time,
                    @constraint(
                        model,
                        sum((1 - unit.var.ison[_t]) for _t in t:(T_min_off[t].t_end)) >=
                        T_min_off[t].max_dur * (prev - unit.var.ison[t]),
                        base_name = make_base_name(unit, "min_off_time", t)
                    )
                )
            end
        end
    end

    return nothing
end
