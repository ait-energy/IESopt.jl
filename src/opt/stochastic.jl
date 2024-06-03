# todo:
# - needs the same global parameters as the usual optimize!
# - does not work with binary variables in addons...

using ProgressMeter

mutable struct StochasticData4
    main::JuMP.Model
    subs::Vector{JuMP.Model}

    scenarios::Vector{Dict}
    decisions::Vector{String}

    max_rel_gap::Float64
    max_iterations::Int64
    max_time_s::Int64

    initial_lower_bound::Float64

    iteration::Int64
    cuts::Int64

    user_defined_variables::Set{Symbol}

    function StochasticData4(main::JuMP.Model)
        return new(main, Vector{JuMP.Model}(), Vector{Dict}(), Vector{String}(), 1e-4, -1, -1, 0.0, 0, 0, Set())
    end

    function StochasticData4(
        main::JuMP.Model,
        max_rel_gap::Float64,
        max_iterations::Int64,
        max_time_s::Int64,
        initial_lb::Float64,
    )
        return new(
            main,
            Vector{JuMP.Model}(),
            Vector{Dict}(),
            Vector{String}(),
            max_rel_gap,
            max_iterations,
            max_time_s,
            initial_lb,
            0,
            0,
            Set(),
        )
    end
end
StochasticData = StochasticData4

"""
    function stochastic(
        optimizer::DataType,
        filename::String;
        opt_attr_main::Dict=Dict(),
        opt_attr_sub::Dict=Dict(),
        rel_gap::Float64=1e-4,
        max_iterations::Int64=-1,
        max_time_s::Int64=-1,
        suppress_log_lvl::Logging.LogLevel=Logging.Warn,
    )

TODO!
```
"""
function stochastic(
    optimizer::DataType,
    filename::String;
    opt_attr_main::Dict=Dict(),
    opt_attr_sub::Dict=Dict(),
    rel_gap::Float64=1e-4,
    max_iterations::Int64=-1,
    max_time_s::Int64=-1,
    initial_lb::Float64=0.0,
    suppress_log_lvl::Logging.LogLevel=Logging.Warn,
    user_defined::Dict{Symbol, Set{Symbol}}=Dict(:main => Set{Symbol}(), :sub => Set{Symbol}()),
    feasibility_penalty::Float64=1e6,
    kwargs...,
)
    _stoch_warning = "Using automatic Benders decomposition for Decision optimization is an advanced feature, that \
                     requires a carefully crafted model. Ensure that you are familiar with what is necessary or \
                     consult with someone before trying this. The most important points are: (1) ensured \
                     feasibility of the sub-problem, (2) the sub-problem being pure-LP, (3) the correct solver \
                     using advanced MILP formulations in the main-problem, (4) a correct `problem_type` setting \
                     in the config file corresponding to the problem type of the main-problem. Furthermore, result \
                     extraction has to be done manually, and model handling / return values look differently."
    @warn "[stochastic] $_stoch_warning"

    _model_main = JuMP.direct_model(JuMP.optimizer_with_attributes(optimizer, opt_attr_main...))
    stochastic_data = StochasticData(_model_main, rel_gap, max_iterations, max_time_s, initial_lb)

    @info "[stochastic] Parsing model into main" filename

    # Update logging.
    initial_log_lvl = Logging.min_enabled_level(Logging.current_logger())
    Logging.disable_logging(suppress_log_lvl)

    # Do the parse for the main-problem.
    if !parse!(stochastic_data.main, filename; kwargs...)
        @error "[stochastic] `parse!(...) failed (MAIN)"
        return stochastic_data
    end

    # Restore logging.
    Logging.disable_logging(initial_log_lvl)

    @info "[stochastic] Preparing scenarios" filename
    if stochastic_data.main.ext[:stochastic][:base_config]["scenarios"] == "all"
        _values = values(stochastic_data.main.ext[:stochastic][:base_config]["parameters"])
        _keys = keys(stochastic_data.main.ext[:stochastic][:base_config]["parameters"])
        _zipped = vec(collect(Iterators.product(_values...)))

        for scenario in _zipped
            push!(stochastic_data.scenarios, Dict(zip(_keys, scenario)))
        end
    else
        @error "[stochastic] Scenario mode currently not supported" mode =
            stochastic_data.main.ext[:stochastic][:base_config]["scenarios"]
        return stochastic_data
    end
    @info "[stochastic] Scenarios prepared" number = length(stochastic_data.scenarios)

    @info "[stochastic] Parsing model into sub-problems" filename

    # Update logging.
    initial_log_lvl = Logging.min_enabled_level(Logging.current_logger())
    Logging.disable_logging(suppress_log_lvl)

    for scenario in stochastic_data.scenarios
        _model_sub = JuMP.direct_model(JuMP.optimizer_with_attributes(optimizer, opt_attr_sub...))
        if !parse!(_model_sub, filename; Dict(Symbol(k) => v for (k, v) in merge(kwargs, scenario))...)
            @error "[stochastic] `parse!(...) failed (SUB)"
            return stochastic_data
        end
        push!(stochastic_data.subs, _model_sub)
    end

    # Restore logging.
    Logging.disable_logging(initial_log_lvl)

    # Scan for Decisions / non-Decisions.
    _cname_non_decisions = []
    for (cname, component) in stochastic_data.main.ext[:iesopt].model.components
        if component isa Decision
            push!(stochastic_data.decisions, cname)
        else
            push!(_cname_non_decisions, cname)
        end
    end

    # Disable everything that is not a Decision in the main-problem.
    @info "[stochastic] Modify main model"
    for cname in _cname_non_decisions
        delete!(stochastic_data.main.ext[:iesopt].model.components, cname)
    end

    # Build main-problem.
    @info "[stochastic] Building main model"
    build!(stochastic_data.main)

    # Modify Decisions in sub-problem.
    @info "[stochastic] Modifying sub models with fixed Decisions"

    # Update logging.
    initial_log_lvl = Logging.min_enabled_level(Logging.current_logger())
    Logging.disable_logging(suppress_log_lvl)

    @showprogress "Modifying sub models: " for sub in stochastic_data.subs
        for comp_name in stochastic_data.decisions
            component(sub, comp_name).mode = :fixed
            component(sub, comp_name).cost = nothing
            component(sub, comp_name).fixed_cost = nothing
            component(sub, comp_name).fixed_value = 0.0
        end
    end

    # Restore logging.
    Logging.disable_logging(initial_log_lvl)

    # Build sub-problems.
    @info "[stochastic] Build sub models"

    # Update logging.
    initial_log_lvl = Logging.min_enabled_level(Logging.current_logger())
    Logging.disable_logging(suppress_log_lvl)

    @showprogress "Building sub models: " for sub in stochastic_data.subs
        build!(sub)
    end

    # Restore logging.
    Logging.disable_logging(initial_log_lvl)

    @warn "[stochastic] Stochastic optimization does currently not support user defined functionality; if you are using Addons reconsider"

    # Add the new variable and modify the objective of the main-problem.
    @info "[stochastic] Modify main model and add initial cut"
    n_subs = length(stochastic_data.subs)
    @variable(stochastic_data.main, θ[s=1:n_subs], lower_bound = stochastic_data.initial_lower_bound)
    @objective(stochastic_data.main, Min, JuMP.objective_function(stochastic_data.main) + sum(θ) / n_subs)

    # Permanently silence sub-problems.
    for sub in stochastic_data.subs
        JuMP.set_silent(sub)
    end

    # Check constraints safety.
    if !isempty(stochastic_data.main.ext[:iesopt].aux.constraint_safety_penalties)
        @info "[stochastic] Relaxing constraints based on constraint_safety (MAIN)"
        stochastic_data.main.ext[:constraint_safety_expressions] = JuMP.relax_with_penalty!(
            stochastic_data.main,
            Dict(k => v.penalty for (k, v) in stochastic_data.main.ext[:iesopt].aux.constraint_safety_penalties),
        )
    end
    if !isempty(stochastic_data.subs[1].ext[:iesopt].aux.constraint_safety_penalties)
        @info "[stochastic] Relaxing constraints based on constraint_safety (SUBs)"
        @showprogress "Modifying sub models: " for sub in stochastic_data.subs
            sub.ext[:constraint_safety_expressions] = JuMP.relax_with_penalty!(
                sub,
                Dict(k => v.penalty for (k, v) in sub.ext[:iesopt].aux.constraint_safety_penalties),
            )
        end
    end

    # Choose the correct approach to handle the main-problem.
    if _is_lp(stochastic_data.main)
        @info "[stochastic] LP main detected, starting iterative mode"
        _iterative_stochastic(stochastic_data)
    elseif !JuMP.MOI.supports(JuMP.backend(stochastic_data.main), JuMP.MOI.LazyConstraintCallback())
        @warn "[stochastic] Solver does not support lazy callbacks, forcing iterative mode with possibly lower performance"
        @info "[stochastic] Starting iterative mode"
        _iterative_stochastic(stochastic_data)
    else
        @warn "[stochastic] Callback mode is currently not implemented, defaulting down to iterative mode"
        @info "[stochastic] Starting iterative mode"
        _iterative_stochastic(stochastic_data)

        # @info "[stochastic] MILP main detected, starting callback mode"
        # if (stochastic_data.max_iterations > 0) || (stochastic_data.max_time_s > 0)
        #     @error "[stochastic] Callback mode does not support time/iteration limits currently"
        # end

        # @info "[stochastic] Register callback for main model"
        # custom_callback = (cb_data) -> _cb_stochastic(stochastic_data, cb_data)
        # JuMP.set_attribute(stochastic_data.main, JuMP.MOI.LazyConstraintCallback(), custom_callback)

        # @info "[stochastic] Start MILP optimize"
        # JuMP.optimize!(stochastic_data.main)
        # @info "[stochastic] Finished optimization" inner_iterations = stochastic_data.iteration cuts = stochastic_data.cuts
    end

    return stochastic_data
end

function _cb_stochastic(benders_data::BendersData, cb_data::Any)
    @error "[stochastic] Callback mode currently not implemented"
end

function _iterative_stochastic(stochastic_data::StochasticData)
    # Silence the main-problem since it will be called often.
    JuMP.set_silent(stochastic_data.main)

    println("")
    println("  iter.  |  lower bnd.  |  upper bnd.  |   rel. gap   |   time (s)   ")
    println("---------+--------------+--------------+--------------+--------------")
    t_start = Dates.now()

    rel_gap = Inf
    best_ub = Inf
    while true
        stochastic_data.iteration += 1

        current_decisions = Dict()

        # Solve the main-problem.
        JuMP.optimize!(stochastic_data.main)

        # Obtain the solution from the main-problem.
        current_decisions = Dict(
            comp_name => extract_result(stochastic_data.main, comp_name, "value"; mode="value") for
            comp_name in stochastic_data.decisions
        )

        # Update the sub-problems.
        for sub in stochastic_data.subs
            for (comp_name, value) in current_decisions
                JuMP.fix(component(sub, comp_name).var.value, value; force=true)
            end
        end

        # Solve the sub-problems.
        for i in eachindex(stochastic_data.subs)
            sub = stochastic_data.subs[i]
            JuMP.optimize!(sub)

            if JuMP.result_count(sub) == 0
                @error "[stochastic] Could not solve sub-problem" scenario = stochastic_data.scenarios[i]
                return stochastic_data
            end
        end

        # Calculate bounds and current gap.
        obj_subs = collect(JuMP.objective_value(sub) for sub in stochastic_data.subs)
        obj_lb = JuMP.objective_value(stochastic_data.main)
        obj_ub = obj_lb - sum(JuMP.value.(stochastic_data.main[:θ])) + sum(obj_subs)
        best_ub = min(best_ub, obj_ub)
        rel_gap = ((best_ub != 0.0) ? abs((best_ub - obj_lb) / best_ub) : (obj_lb == 0 ? 0.0 : Inf))

        # Info print
        t_elapsed = Dates.Millisecond((Dates.now() - t_start)).value / 1000.0
        _print_iteration(stochastic_data.iteration, obj_lb, best_ub, rel_gap, t_elapsed)

        # Check abortion criteria.
        if (stochastic_data.max_rel_gap > 0) && (rel_gap <= stochastic_data.max_rel_gap)
            println("")
            @info "[stochastic] Terminating iterative optimization" reason = "relative gap reached" time =
                round(t_elapsed; digits=2) iterations = stochastic_data.iteration gap = rel_gap obj = obj_ub best_ub
            break
        end
        if (stochastic_data.max_time_s > 0) && (t_elapsed >= stochastic_data.max_time_s)
            println("")
            @info "[stochastic] Terminating iterative optimization" reason = "time limit reached" time =
                round(t_elapsed; digits=2) iterations = stochastic_data.iteration gap = rel_gap obj = obj_ub best_ub
            break
        end
        if (stochastic_data.max_iterations > 0) && (stochastic_data.iteration >= stochastic_data.max_iterations)
            println("")
            @info "[stochastic] Terminating iterative optimization" reason = "iteration limit reached" time =
                round(t_elapsed; digits=2) iterations = stochastic_data.iteration gap = rel_gap obj = obj_ub best_ub
            break
        end

        # Add the new constraint.
        for i in 1:length(stochastic_data.subs)
            cut = JuMP.@constraint(
                stochastic_data.main,
                stochastic_data.main[:θ][i] >=
                obj_subs[i] + sum(
                    extract_result(stochastic_data.subs[i], comp_name, "value"; mode="dual") *
                    (component(stochastic_data.main, comp_name).var.value - value) for
                    (comp_name, value) in current_decisions
                )
            )
            stochastic_data.cuts += 1
        end

        # todo: save cuts
        # todo: track cuts and disable them after X iterations of not being binding
    end
end
