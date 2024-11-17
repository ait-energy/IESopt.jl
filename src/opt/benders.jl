# todo:
# - needs the same global parameters as the usual optimize!
# - does not work with binary variables in addons...

mutable struct BendersData
    main::JuMP.Model
    sub::JuMP.Model

    decisions::Vector{String}

    max_rel_gap::Float64
    max_iterations::Int64
    max_time_s::Int64

    initial_lower_bound::Float64

    iteration::Int64
    cuts::Int64

    user_defined_variables::Set{Symbol}

    function BendersData(main::JuMP.Model, sub::JuMP.Model, decisions::Vector{String})
        return new(main, sub, decisions, 1e-4, -1, -1, 0.0, 0, 0, Set())
    end

    function BendersData(
        main::JuMP.Model,
        sub::JuMP.Model,
        decisions::Vector{String},
        max_rel_gap::Float64,
        max_iterations::Int64,
        max_time_s::Int64,
        initial_lb::Float64,
    )
        return new(main, sub, decisions, max_rel_gap, max_iterations, max_time_s, initial_lb, 0, 0, Set())
    end
end

"""
    function benders(
        optimizer::DataType,
        filename::String;
        opt_attr_main::Dict=Dict(),
        opt_attr_sub::Dict=Dict(),
        rel_gap::Float64=1e-4,
        max_iterations::Int64=-1,
        max_time_s::Int64=-1,
        suppress_log_lvl::Logging.LogLevel=Logging.Warn,
    )

Perform automatic Benders decomposition for all Decisions in the model. 

Example usage:

```
import IESopt
import HiGHS

oas_highs = Dict(
    "solver" => "choose",
    "run_crossover" => "off",
    "primal_feasibility_tolerance" => 1e-3,
    "dual_feasibility_tolerance" => 1e-3,
    "ipm_optimality_tolerance" => 1e-3
)

IESopt.benders(HiGHS.Optimizer, "model/config.iesopt.yaml"; opt_attr_sub=oas_highs)
```

```
import IESopt
import Gurobi

oas_gurobi = Dict(
    "Method" => 2,
    "Crossover" => 0,
    "Presolve" => 2,
    "OptimalityTol" => 1e-3,
    "FeasibilityTol" => 1e-3,
    "BarConvTol" => 1e-3,
)

IESopt.benders(Gurobi.Optimizer, "model/config.iesopt.yaml"; opt_attr_sub=oas_gurobi)
```
"""
function benders(
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
    _benders_warning = "Using automatic Benders decomposition for Decision optimization is an advanced feature, that \
                       requires a carefully crafted model. Ensure that you are familiar with what is necessary or \
                       consult with someone before trying this. The most important points are: (1) ensured \
                       feasibility of the sub-problem, (2) the sub-problem being pure-LP, (3) the correct solver \
                       using advanced MILP formulations in the main-problem, (4) a correct `problem_type` setting \
                       in the config file corresponding to the problem type of the main-problem. Furthermore, result \
                       extraction has to be done manually, and model handling / return values look differently."
    @warn "[benders] $_benders_warning"

    _model_main = JuMP.direct_model(JuMP.optimizer_with_attributes(optimizer, opt_attr_main...))
    _model_sub = JuMP.direct_model(JuMP.optimizer_with_attributes(optimizer, opt_attr_sub...))

    benders_data =
        BendersData(_model_main, _model_sub, Vector{String}(), rel_gap, max_iterations, max_time_s, initial_lb)

    @info "[benders] Parsing model into main/sub" filename

    # Ignore everything below Error for now.
    initial_log_lvl = Logging.min_enabled_level(Logging.current_logger())
    Logging.disable_logging(suppress_log_lvl)

    # Do the parse.
    if !parse!(benders_data.main, filename; kwargs...)
        @error "[benders] `parse!(...) failed (MAIN)"
        return benders_data
    end
    if !parse!(benders_data.sub, filename; kwargs...)
        @error "[benders] `parse!(...) failed (SUB)"
        return benders_data
    end

    # Restore logging.
    Logging.disable_logging(initial_log_lvl)

    # Scan for Decisions / non-Decisions.
    _cname_non_decisions = []
    for (cname, component) in benders_data.main.ext[:_iesopt].model.components
        if component isa Decision
            push!(benders_data.decisions, cname)
        else
            push!(_cname_non_decisions, cname)
        end
    end

    # Disable everything that is not a Decision in the main-problem.
    @info "[benders] Modify main model"
    for cname in _cname_non_decisions
        delete!(benders_data.main.ext[:_iesopt].model.components, cname)
    end

    # Build main-problem.
    @info "[benders] Building main model"
    build!(benders_data.main)

    # Modify Decisions in sub-problem.
    @info "[benders] Modifying sub model with fixed Decisions"
    for comp_name in benders_data.decisions
        get_component(benders_data.sub, comp_name).mode = :fixed
        get_component(benders_data.sub, comp_name).cost = nothing
        get_component(benders_data.sub, comp_name).fixed_cost = nothing
        get_component(benders_data.sub, comp_name).fixed_value = 0.0
    end

    # Build sub-problem.
    @info "[benders] Build sub model"
    build!(benders_data.sub)

    # ======================
    # JuMP.@variable(benders_data.main, _x >= 0)
    # JuMP.@variable(benders_data.sub, _x >= 0)

    # JuMP.@constraint(benders_data.main, _c, benders_data.main[:_x] >= get_component(benders_data.main, "invest1_1").var.value)
    # JuMP.@constraint(benders_data.sub, _c, benders_data.sub[:_x] >= get_component(benders_data.sub, "invest1_1").var.value)

    # user_defined = Dict(
    #     :main => Set([:_x]), :sub => Set([:_x, :_c])
    # )
    # ======================

    # Check for user-defined objects that need to be split.
    objects = keys(JuMP.object_dictionary(benders_data.main))
    constraint_relaxed_in_sub = false
    if length(objects) > 0
        @info "[benders] Found user-defined objects, starting partial delete; make sure to name ALL your objects, and that you are not accessing objects that may not be constructed in the sub-problem (Decisions)" n =
            length(objects)

        for obj in objects
            in_main = false
            in_sub = false

            if !(obj in user_defined[:main])
                JuMP.delete(benders_data.main, benders_data.main[obj])
                JuMP.unregister(benders_data.main, obj)
            elseif _obj_type(benders_data.main[obj]) === :var
                in_main = true
            end

            if !(obj in user_defined[:sub])
                JuMP.delete(benders_data.sub, benders_data.sub[obj])
                JuMP.unregister(benders_data.sub, obj)
            elseif _obj_type(benders_data.sub[obj]) === :var
                in_sub = true
            else
                JuMP.relax_with_penalty!(benders_data.sub, Dict(benders_data.sub[obj] => feasibility_penalty))
                constraint_relaxed_in_sub = true
            end

            if in_main && in_sub
                push!(benders_data.user_defined_variables, obj)
            end
        end

        if length(benders_data.user_defined_variables) > 0
            @info "[benders] Duplicated user-defined variables found; will be controlled by main-problem; relaxing potential integrality in sub-problem" n =
                length(benders_data.user_defined_variables)
            JuMP.relax_integrality(benders_data.sub)

            if constraint_relaxed_in_sub
                @warn "[benders] At least one constraint in the sub-problem was relaxed with penalized slacks (penalty $(feasibility_penalty)) to try to achieve feasibility"
            end
        end
    end

    # Add the new variable and modify the objective of the main-problem.
    @info "[benders] Modify main model and add initial cut"
    @variable(benders_data.main, θ, lower_bound = benders_data.initial_lower_bound)
    @objective(benders_data.main, Min, JuMP.objective_function(benders_data.main) + θ)

    # Permanently silence sub-problem.
    JuMP.set_silent(benders_data.sub)

    # Check constraints safety.
    if !isempty(benders_data.main.ext[:_iesopt].aux.soft_constraints_penalties)
        @info "[benders] Relaxing constraints based on soft_constraints (MAIN)"
        benders_data.main.ext[:soft_constraints_expressions] = JuMP.relax_with_penalty!(
            benders_data.main,
            Dict(k => v.penalty for (k, v) in benders_data.main.ext[:_iesopt].aux.soft_constraints_penalties),
        )
    end
    if !isempty(benders_data.sub.ext[:_iesopt].aux.soft_constraints_penalties)
        @info "[benders] Relaxing constraints based on soft_constraints (SUB)"
        benders_data.sub.ext[:soft_constraints_expressions] = JuMP.relax_with_penalty!(
            benders_data.sub,
            Dict(k => v.penalty for (k, v) in benders_data.sub.ext[:_iesopt].aux.soft_constraints_penalties),
        )
    end

    # Choose the correct approach to handle the main-problem.
    if _is_lp(benders_data.main)
        @info "[benders] LP main detected, starting iterative mode"
        _iterative_benders(benders_data)
    elseif !JuMP.MOI.supports(JuMP.backend(benders_data.main), JuMP.MOI.LazyConstraintCallback())
        @warn "[benders] Solver does not support lazy callbacks, forcing iterative mode with possibly lower performance"
        @info "[benders] Starting iterative mode"
        _iterative_benders(benders_data)
    else
        @info "[benders] MILP main detected, starting callback mode"
        if (benders_data.max_iterations > 0) || (benders_data.max_time_s > 0)
            @error "[benders] Callback mode does not support time/iteration limits currently"
        end

        @info "[benders] Register callback for main model"
        custom_callback = (cb_data) -> _cb_benders(benders_data, cb_data)
        JuMP.set_attribute(benders_data.main, JuMP.MOI.LazyConstraintCallback(), custom_callback)

        @info "[benders] Start MILP optimize"
        JuMP.optimize!(benders_data.main)
        @info "[benders] Finished optimization" inner_iterations = benders_data.iteration cuts = benders_data.cuts
    end

    return benders_data
end

function _cb_benders(benders_data::BendersData, cb_data::Any)
    if JuMP.callback_node_status(cb_data, benders_data.main) != JuMP.MOI.CALLBACK_NODE_STATUS_INTEGER
        # todo: is this actually better?
        # return
    end

    benders_data.iteration += 1

    # Get the current solution from the main-problem.
    current_decisions = Dict(
        comp_name => JuMP.callback_value(cb_data, get_component(benders_data.main, comp_name).var.value) for
        comp_name in benders_data.decisions
    )
    current_user_defined_variables = Dict(
        obj => JuMP.callback_value.(cb_data, benders_data.main[obj]) for obj in benders_data.user_defined_variables
    )

    # Update the sub-problem.
    for (comp_name, value) in current_decisions
        JuMP.fix(get_component(benders_data.sub, comp_name).var.value, value; force=true)
    end
    for (obj, value) in current_user_defined_variables
        JuMP.fix.(benders_data.sub[obj], value; force=true)
    end

    # Solve the sub-problem.
    JuMP.optimize!(benders_data.sub)
    @assert JuMP.result_count(benders_data.sub) != 0 "could not solve sub-problem"

    # Calculate objective bounds & gap.
    obj_sub = JuMP.objective_value(benders_data.sub)
    obj_lb = JuMP.callback_value(cb_data, JuMP.objective_function(benders_data.main))
    obj_ub = obj_lb - JuMP.callback_value(cb_data, benders_data.main[:θ]) + obj_sub
    rel_gap = (obj_ub != 0.0) ? abs((obj_ub - obj_lb) / obj_ub) : (obj_lb == 0 ? 0.0 : Inf)

    if rel_gap <= benders_data.max_rel_gap
        return
    end

    # Add the new constraint.
    if length(benders_data.user_defined_variables) > 0
        @warn "[benders] NOT FULLY IMPLEMENTED (for non arrays, ...)" maxlog = 1
        user_sum = sum(
            sum(
                JuMP.reduced_cost.(benders_data.sub[obj].data) .*
                (benders_data.main[obj].data .- current_user_defined_variables[obj].data),
            ) for obj in benders_data.user_defined_variables
        )
    else
        user_sum = 0
    end
    cut = JuMP.@build_constraint(
        benders_data.main[:θ] >=
        obj_sub +
        sum(
            extract_result(benders_data.sub, comp_name, "value"; mode="dual") *
            (get_component(benders_data.main, comp_name).var.value - value) for
            (comp_name, value) in current_decisions
        ) +
        user_sum
    )

    JuMP.MOI.submit(benders_data.main, JuMP.MOI.LazyConstraint(cb_data), cut)
    benders_data.cuts += 1

    return
end

function _iterative_benders(benders_data::BendersData; exploration_iterations=0)
    # Silence the main-problem since it will be called often.
    JuMP.set_silent(benders_data.main)

    println("")
    println("  iter.  |  lower bnd.  |  upper bnd.  |   rel. gap   |   time (s)   ")
    println("---------+--------------+--------------+--------------+--------------")
    t_start = Dates.now()

    rel_gap = Inf
    best_ub = Inf
    while true
        benders_data.iteration += 1

        current_decisions = Dict()
        current_user_defined_variables = Dict()
        exploration = false

        if (benders_data.iteration <= exploration_iterations) && isempty(benders_data.user_defined_variables)
            # Random values in the beginning to explore.
            for comp_name in benders_data.decisions
                comp = get_component(benders_data.main, comp_name)
                lb = !isnothing(comp.lb) ? comp.lb : -500
                ub = !isnothing(comp.ub) ? comp.ub : 500
                current_decisions[comp_name] = lb + rand() * (ub - lb)
            end

            exploration = true
        else
            # Solve the main-problem.
            JuMP.optimize!(benders_data.main)

            # Obtain the solution from the main-problem.
            current_decisions = Dict(
                comp_name => extract_result(benders_data.main, comp_name, "value"; mode="value") for
                comp_name in benders_data.decisions
            )
            current_user_defined_variables =
                Dict(obj => JuMP.value.(benders_data.main[obj]) for obj in benders_data.user_defined_variables)
        end

        # Update the sub-problem.
        for (comp_name, value) in current_decisions
            JuMP.fix(get_component(benders_data.sub, comp_name).var.value, value; force=true)
        end
        for (obj, value) in current_user_defined_variables
            JuMP.fix.(benders_data.sub[obj], value; force=true)
        end

        # Solve the sub-problem.
        JuMP.optimize!(benders_data.sub)

        if JuMP.result_count(benders_data.sub) == 0
            @error "[benders] Could not solve sub-problem"
            return benders_data
        end

        exploration_sum = 0.0
        if exploration
            exploration_dict = Dict(
                get_component(benders_data.main, comp_name).var.value => current_decisions[comp_name] for
                comp_name in benders_data.decisions
            )
            exploration_dict[benders_data.main[:θ]] = 0.0
            exploration_sum = JuMP.value(_var -> exploration_dict[_var], JuMP.objective_function(benders_data.main))
        end

        # Calculate bounds and current gap.
        obj_sub = JuMP.objective_value(benders_data.sub)
        obj_lb = exploration ? exploration_sum : JuMP.objective_value(benders_data.main)
        obj_ub = obj_lb - (exploration ? 0.0 : JuMP.value(benders_data.main[:θ])) + obj_sub
        best_ub = min(best_ub, obj_ub)
        rel_gap = exploration ? Inf : ((best_ub != 0.0) ? abs((best_ub - obj_lb) / best_ub) : (obj_lb == 0 ? 0.0 : Inf))

        # Info print
        t_elapsed = Dates.Millisecond((Dates.now() - t_start)).value / 1000.0
        _print_iteration(benders_data.iteration, obj_lb, best_ub, rel_gap, t_elapsed)

        # Check abortion criteria.
        if (benders_data.max_rel_gap > 0) && (rel_gap <= benders_data.max_rel_gap)
            println("")
            @info "[benders] Terminating iterative optimization" reason = "relative gap reached" time =
                round(t_elapsed; digits=2) iterations = benders_data.iteration gap = rel_gap obj = obj_ub best_ub
            break
        end
        if (benders_data.max_time_s > 0) && (t_elapsed >= benders_data.max_time_s)
            println("")
            @info "[benders] Terminating iterative optimization" reason = "time limit reached" time =
                round(t_elapsed; digits=2) iterations = benders_data.iteration gap = rel_gap obj = obj_ub best_ub
            break
        end
        if (benders_data.max_iterations > 0) && (benders_data.iteration >= benders_data.max_iterations)
            println("")
            @info "[benders] Terminating iterative optimization" reason = "iteration limit reached" time =
                round(t_elapsed; digits=2) iterations = benders_data.iteration gap = rel_gap obj = obj_ub best_ub
            break
        end

        # Add the new constraint.
        if length(benders_data.user_defined_variables) > 0
            @warn "[benders] NOT FULLY IMPLEMENTED (for non arrays, ...)" maxlog = 1
            user_sum = sum(
                sum(
                    JuMP.reduced_cost.(benders_data.sub[obj].data) .*
                    (benders_data.main[obj].data .- current_user_defined_variables[obj].data),
                ) for obj in benders_data.user_defined_variables
            )
        else
            user_sum = 0
        end
        cut = JuMP.@constraint(
            benders_data.main,
            benders_data.main[:θ] >=
            obj_sub +
            sum(
                extract_result(benders_data.sub, comp_name, "value"; mode="dual") *
                (get_component(benders_data.main, comp_name).var.value - value) for
                (comp_name, value) in current_decisions
            ) +
            user_sum
        )
        benders_data.cuts += 1

        # todo: save cuts
        # todo: track cuts and disable them after X iterations of not being binding
    end
end
