"""
    IESopt

A general purpose solver agnostic energy system optimization framework.
"""
module IESopt

include("imports.jl")

include("utils/utils.jl")
include("config/config.jl")
include("core.jl")
include("parser.jl")
# include("opt/opt.jl")
include("results/results.jl")
include("validation/validation.jl")
include("templates/templates.jl")
# include("texify/texify.jl")

function _build_model!(model::JuMP.Model)
    if @config(model, general.performance.string_names, Bool) != model.set_string_names_on_creation
        new_val = @config(model, general.performance.string_names, Bool)
        @info "Overwriting `string_names_on_creation` to `$(new_val)` based on config"
        JuMP.set_string_names_on_creation(model, new_val)
    end

    # This specifies the order in which components are built. This ensures that model parts that are used later on, are
    # already initialized (e.g. constructing a constraint may use expressions and variables).
    build_order = [
        _setup!,
        _construct_expressions!,
        _after_construct_expressions!,
        _construct_variables!,
        _after_construct_variables!,
        _construct_constraints!,
        _after_construct_constraints!,
        _construct_objective!,
    ]::Vector{Function}

    # TODO: care about components/global addons returning false somewhere

    @info "Preparing components"

    # Sort components by their build priority.
    # For instance, Decisions with a default build priority of 1000 are built before all other components
    # with a default build priority of 0.
    # Components with a negative build priority are not built at all.
    corder =
        sort(collect(values(internal(model).model.components)); by=_build_priority, rev=true)::Vector{<:_CoreComponent}

    @info "Start creating JuMP model"

    progress_enabled = @config(model, general.verbosity.progress, String) == "on"
    for f in build_order
        # Construct all components, building them in the necessary order.
        progress_map(
            corder;
            mapfun=foreach,
            progress=Progress(length(corder); enabled=progress_enabled, desc="$(Symbol(f)) ..."),
        ) do component
            if _build_priority(component) >= 0
                internal(model).debug = "$(component.name) :: $(f)"
                f(component)::Nothing
            end
        end

        # Call global addons
        if _has_addons(model)
            addon_fi = Symbol(string(f)[2:end])
            for (name, prop) in internal(model).input.addons
                # Only execute a function if it exists.
                if addon_fi in names(prop.addon; all=true)
                    @info "Invoking addon" addon = name step = addon_fi
                    if !Base.invokelatest(getfield(prop.addon, addon_fi), model, prop.config)
                        @critical "Addon returned error" addon = name step = addon_fi
                    end
                end
            end
        end
    end

    @info "Finalizing Virtuals"
    for component in corder
        component isa Virtual || continue
        finalizers = component._finalizers::Vector{Function}
        for i in reverse(eachindex(finalizers))
            finalizers[i](component)
        end
    end

    # Construct relevant ETDF constraints.
    if !isempty(internal(model).aux.etdf.groups)
        @error "ETDF constraints are currently not supported"
        # for (etdf_group, node_ids) in internal(model).aux.etdf.groups
        #     internal(model).aux.etdf.constr[etdf_group] = @constraint(
        #         model,
        #         [t = get_T(model) ],
        #         sum(internal(model).model.components[id].exp.injection[t] for id in node_ids) == 0
        #     )
        # end
    end

    # Building the objective(s).
    for (name, obj) in internal(model).model.objectives
        @info "Preparing objective" name

        # Add all terms that were added from within a component definition to the correct objective's terms.
        for term in internal(model).aux._obj_terms[name]
            if term isa Number
                push!(obj.constants, term)
            else
                comp, proptype, prop = rsplit(term, "."; limit=3)
                field = getproperty(getproperty(get_component(model, comp), Symbol(proptype)), Symbol(prop))
                if field isa Vector
                    push!(obj.terms, sum(field))
                else
                    push!(obj.terms, field)
                end
            end
        end

        # todo: is there a faster way to sum up a set of expressions?
        @info "Building objective" name
        for term in obj.terms
            JuMP.add_to_expression!(obj.expr, term)
        end
        if !isempty(obj.constants)
            JuMP.add_to_expression!(obj.expr, sum(obj.constants))
        end
    end

    if !_is_multiobjective(model)
        current_objective = @config(model, optimization.objective.current)
        isnothing(current_objective) && @critical "Missing an active objective"
        @objective(model, Min, internal(model).model.objectives[current_objective].expr)
    else
        @objective(
            model,
            Min,
            [internal(model).model.objectives[obj].expr for obj in @config(model, optimization.multiobjective.terms)]
        )
    end
end

function _prepare_model!(model::JuMP.Model)
    # Potentially remove components that are tagged `conditional`, and violate some of their conditions.
    failed_components = []
    for (cname, component) in internal(model).model.components
        !_check(component) && push!(failed_components, cname)
    end
    if length(failed_components) > 0
        @warn "Some components are removed based on the `conditional` setting" n_components = length(failed_components)
        for cname in failed_components
            delete!(internal(model).model.components, cname)
        end
    end

    # Init global addons before preparing components
    if _has_addons(model)
        for (name, prop) in internal(model).input.addons
            if !Base.invokelatest(prop.addon.initialize!, model, prop.config)
                @critical "Addon failed to set up" name
            end
        end
    end

    # Fully prepare each component.
    all_components_ok = true
    for (id, component) in internal(model).model.components
        all_components_ok &= _prepare!(component)
    end
    if !all_components_ok
        error("Some components did not pass the preparation step.")
    end
end

"""
    run(filename::String; kwargs...)

Build, optimize, and return a model.

# Arguments

- `filename::String`: The path to the top-level configuration file.

# Keyword Arguments

Keyword arguments are passed to the [`normpath(__dir, !`](@ref) function.
"""
function run(
    filename::String;
    parameters::Union{Nothing, Dict}=nothing,
    config::Union{Nothing, Dict}=nothing,
    addons::Union{Nothing, Dict}=nothing,
    carriers::Union{Nothing, Dict}=nothing,
    components::Union{Nothing, Dict}=nothing,
    load_components::Union{Nothing, Dict}=nothing,
    skip_validation::Bool=false,
)
    @nospecialize parameters config addons carriers components load_components

    model = generate!(filename; parameters, config, addons, carriers, components, load_components, skip_validation)

    if pop!(model.ext, :_iesopt_failed_generate, false)
        @error "Errors in model generation; skipping optimization"
        return model
    end

    try
        optimize!(model)
    catch
        @error "Errors in model optimization"
    end

    return model
end

"""
    generate!(filename::String; @nospecialize(kwargs...))

Generate an IESopt model based on the top-level config in `filename`.

# Arguments
- `filename::String`: The name of the file to load.

# Keyword Arguments
To be documented.

# Returns
- `model::JuMP.Model`: The generated IESopt model.
"""
function generate!(
    filename::String;
    parameters::Union{Nothing, Dict}=nothing,
    config::Union{Nothing, Dict}=nothing,
    addons::Union{Nothing, Dict}=nothing,
    carriers::Union{Nothing, Dict}=nothing,
    components::Union{Nothing, Dict}=nothing,
    load_components::Union{Nothing, Dict}=nothing,
    skip_validation::Bool=false,
)
    @nospecialize parameters config addons carriers components load_components

    model = JuMP.Model()::JuMP.Model
    generate!(model, filename; parameters, config, addons, carriers, components, load_components, skip_validation)

    return model::JuMP.Model
end

"""
    generate!(model::JuMP.Model, filename::String; kwargs...)

Generates an IESopt model from a given file and attaches an optimizer if necessary.

# Arguments
- `model::JuMP.Model`: The JuMP model to be used.
- `filename::String`: The path to the file containing the model definition.

# Keyword Arguments
To be documented.

# Returns
- `model::JuMP.Model`: The generated IESopt model.

# Notes
- The function validates the file before parsing and building the model.
- If the model is not in DIRECT mode and has no optimizer attached, an optimizer is attached.
- The function logs the model generation process and handles any exceptions that occur during generation.
- If an error occurs, detailed debug information and the stack trace are logged.
"""
function generate!(
    model::JuMP.Model,
    filename::String;
    parameters::Union{Nothing, Dict}=nothing,
    config::Union{Nothing, Dict}=nothing,
    addons::Union{Nothing, Dict}=nothing,
    carriers::Union{Nothing, Dict}=nothing,
    components::Union{Nothing, Dict}=nothing,
    load_components::Union{Nothing, Dict}=nothing,
    skip_validation::Bool=false,
)
    @nospecialize parameters config addons carriers components load_components

    # local stats_parse, stats_build, stats_total
    # TODO: "re-enable" by refactoring to TimerOutputs

    try
        if !skip_validation
            @info "Performing validation; this can be turned off (by passing `skip_validation = true`) since it takes quite some time" filename
            # Validate before parsing.
            !validate(filename) && return nothing
        end

        # Parse & build the model.
        parse!(model, filename; parameters, config, addons, carriers, components, load_components) || return model
        with_logger(_iesopt_logger(model)) do
            if JuMP.mode(model) != JuMP.DIRECT && JuMP.MOIU.state(JuMP.backend(model)) == JuMP.MOIU.NO_OPTIMIZER
                _attach_optimizer(model)
            end

            build!(model)

            @info "Finished model generation"
        end

        model.ext[:_iesopt_failed_generate] = false

        # NOTE: See below for "timed" sections.
        # stats_total = @timed begin
        #     stats_parse = @timed parse!(model, filename; kwargs...)
        #     !stats_parse.value && return model
        #     if JuMP.mode(model) != JuMP.DIRECT && JuMP.MOIU.state(JuMP.backend(model)) == JuMP.MOIU.NO_OPTIMIZER
        #         with_logger(_iesopt_logger(model)) do
        #             return _attach_optimizer(model)
        #         end
        #     end
        #     stats_build = @timed with_logger(_iesopt_logger(model)) do
        #         return build!(model)
        #     end
        # end
    catch
        # Get debug information from model, if available.
        debug = haskey(model.ext, :iesopt) ? internal(model).debug : "not available"
        debug = isnothing(debug) ? "not available" : debug

        # Get ALL current exceptions.
        curr_ex = current_exceptions()

        # These modules are automatically removed from the backtrace that is shown.
        remove_modules = [:VSCodeServer, :Base, :CoreLogging]

        # Prepare all exceptions.
        _exceptions = []
        for (exception, backtrace) in curr_ex
            trace = stacktrace(backtrace)

            # Debug log the full backtrace.
            @debug "Details on error #$(length(_exceptions) + 1)" error = (exception, trace)

            # Error log the backtrace, but remove modules that only clutter the trace.
            trace = [e for e in trace if !isnothing(parentmodule(e)) && !(nameof(parentmodule(e)) in remove_modules)]
            push!(
                _exceptions,
                Symbol(" = = = = = = = = = [ Error #$(length(_exceptions) + 1) ] = = = = = = = =") =>
                    (exception, trace),
            )
        end

        @error "Error(s) during model generation" debug number_of_errors = length(curr_ex) _exceptions...
        model.ext[:_iesopt_failed_generate] = true
    else
        # with_logger(_iesopt_logger(model)) do
        #     @info "Finished model generation" times =
        #         (parse=stats_parse.time, build=stats_build.time, total=stats_total.time)
        # end
    end

    return model
end

_setoptnow(model::JuMP.Model, ::Val{:none}, moa::Bool) = @critical "This code should never be reached"

function _attach_optimizer(model::JuMP.Model)
    @info "Setting up Optimizer"

    solver_name = @config(model, optimization.solver.name)
    solver = get(
        Dict{String, Symbol}(
            "highs" => :HiGHS,
            "gurobi" => :Gurobi,
            "cbc" => :Cbc,
            "glpk" => :GLPK,
            "cplex" => :CPLEX,
            "ipopt" => :Ipopt,
            "scip" => :SCIP,
        ),
        lowercase(solver_name),
        :unknown,
    )::Symbol

    if solver == :unknown
        @critical "Can't determine proper solver" solver_name
    end

    if @config(model, optimization.solver.mode) == "direct"
        @critical "Automatic direct mode is currently not supported"
    end

    if solver == :HiGHS
        if _is_multiobjective(model)
            JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(HiGHS.Optimizer))
        else
            JuMP.set_optimizer(model, HiGHS.Optimizer)
        end
    else
        try
            @info "Trying to import solver interface" solver
            # Main.eval(Meta.parse("import $(solver)"))
            Base.require(@__MODULE__, solver)
        catch
            rethrow(ErrorException("Failed to setup solver interface; please install it manually"))
            # @info "Solver interface could not be imported; trying to install and precompile it" solver
            # try
            #     Pkg.add(solver)
            #     Pkg.resolve()
            #     @info "Trying to import solver interface" solver
            #     Main.eval(Meta.parse("import $(solver)"))
            # catch
            #     @critical "Failed to setup solver interface; please install it manually" solver
            # end
            # @error "Solver interface installed, but you need to manually reload; please execute your code again"
            # rethrow(ErrorException("Please execute your code again"))
        end

        Base.retry_load_extensions()
        Base.invokelatest(_setoptnow, model, Val{solver}(), false)
    end

    if _is_multiobjective(model)
        moa_mode = @config(model, optimization.multiobjective.mode)
        @info "Setting MOA mode" mode = moa_mode
        JuMP.set_attribute(model, MOA.Algorithm(), eval(Meta.parse("MOA.$moa_mode()")))
    end

    for (attr, value) in @config(model, optimization.solver.attributes)
        try
            @suppress JuMP.set_attribute(model, attr, value)
            @info "Setting attribute" attr value
        catch
            @error "Failed to set attribute" attr value
        end
    end

    if _is_multiobjective(model)
        for (attr, value) in @config(model, optimization.multiobjective.settings)
            try
                if value isa Vector
                    for i in eachindex(value)
                        JuMP.set_attribute(model, eval(Meta.parse("$attr($i)")), value[i])
                    end
                else
                    JuMP.set_attribute(model, eval(Meta.parse("$attr()")), value)
                end
                @info "Setting attribute" attr value
            catch
                @error "Failed to set attribute" attr value
            end
        end
    end

    return nothing
end

"""
    parse!(model::JuMP.Model, filename::AbstractString; kwargs...)

Parse the model configuration from a specified file and update the given `JuMP.Model` object.

# Arguments
- `model::JuMP.Model`: The JuMP model to be updated.
- `filename::AbstractString`: The path to the configuration file. The file must have a `.iesopt.yaml` extension.

# Keyword Arguments
To be documented.

# Returns
- `Bool`: Returns `true` if the model was successfully parsed.

# Errors
- Logs a critical error if the file does not have the `.iesopt.yaml` extension or if there is an error while parsing the model.
"""
function parse!(
    model::JuMP.Model,
    filename::AbstractString;
    parameters::Union{Nothing, Dict}=nothing,
    config::Union{Nothing, Dict}=nothing,
    addons::Union{Nothing, Dict}=nothing,
    carriers::Union{Nothing, Dict}=nothing,
    components::Union{Nothing, Dict}=nothing,
    load_components::Union{Nothing, Dict}=nothing,
)
    @nospecialize

    if !endswith(filename, ".iesopt.yaml")
        @critical "Model entry config files need to respect the `.iesopt.yaml` file extension" filename
    end

    # Get all parameters that were passed directly from the caller.
    global_parameters = something(parameters, Dict{String, Any}())

    # Handle passed "modification" keyword arguments.
    model.ext[:_iesopt_kwargs] = Dict(
        :parameters => parameters,
        :config => config,
        :addons => addons,
        :carriers => carriers,
        :components => components,
        :load_components => load_components,
    )
    # TODO
    isnothing(addons) || @error "The `addons` keyword argument is not yet supported"
    isnothing(carriers) || @error "The `carriers` keyword argument is not yet supported"
    isnothing(components) || @error "The `components` keyword argument is not yet supported"
    isnothing(load_components) || @error "The `load_components` keyword argument is not yet supported"

    # Load the model specified by `filename`.
    _parse_model!(model, filename, global_parameters) || (@critical "Error while parsing model" filename)

    return true
end

"""
    build!(model::JuMP.Model)

Builds and prepares the given IESopt model. This function performs the following steps:

1. Prepares the model by ensuring necessary conversions before performing consistency checks.
2. Checks the consistency of all parsed components in the model.
3. If any component fails the consistency check, an error is raised.
4. Builds the model if all components pass the consistency checks.
5. Logs profiling results after the build process, displaying the top 5 profiling results.

# Arguments
- `model::JuMP.Model`: The IESopt model to be built and prepared.

# Errors
- Raises an error if any component does not pass the consistency check.
"""
function build!(model::JuMP.Model)
    # Prepare the model, ensuring some conversions before consistency checks.
    _prepare_model!(model)

    # Perform conistency checks on all parsed components.
    all_components_ok = true::Bool
    for (id, component) in internal(model).model.components
        all_components_ok &= _isvalid(component)::Bool
    end
    if !all_components_ok
        error("Some components did not pass the consistency check.")
    end

    # Build the model.
    _build_model!(model)

    # @info "Profiling results after `build` [time, top 5]" _profiling_format_top(model, 5)...
    return nothing
end

"""
    optimize!(model::JuMP.Model; kwargs...)

Optimize the given IESopt model with optional keyword arguments.

# Arguments
- `model::JuMP.Model`: The IESopt model to be optimized.
- `kwargs...`: Additional keyword arguments to be passed to the `JuMP.optimize!` function.

# Description
This function performs the following steps:
1. If there are constraint safety penalties, it relaxes the constraints based on these penalties.
2. Sets the verbosity of the solver output based on the model's configuration.
3. Logs the solver output to a file if logging is enabled and supported by the solver.
4. Calls `JuMP.optimize!` to solve the model.
5. Checks the result count and termination status to log the optimization outcome.
6. Analyzes the constraint safety results if there were any constraint safety penalties.
7. Extracts and saves the results if the model is solved and feasible.
8. Profiles the results after optimization.

# Logging
- Logs messages about the relaxation of constraints, solver output, and optimization status.
- Logs warnings if the safety constraint feature is triggered or if unexpected result counts are encountered.
- Logs errors if the solver log file setup fails, if no results are returned, or if extracting results is not possible.

# Returns
- `nothing`: This function does not return any value.
"""
function optimize!(model::JuMP.Model; @nospecialize(kwargs...))
    with_logger(_iesopt_logger(model)) do
        return _optimize!(model; kwargs...)
    end
end

function _optimize!(model::JuMP.Model; @nospecialize(kwargs...))
    if !isempty(internal(model).aux.soft_constraints_penalties)
        @info "Relaxing constraints based on soft_constraints"
        internal(model).aux.soft_constraints_expressions = JuMP.relax_with_penalty!(
            model,
            Dict(k => v.penalty for (k, v) in internal(model).aux.soft_constraints_penalties),
        )
    end

    # Enable or disable solver output
    if @config(model, general.verbosity.solver) == "on"
        JuMP.unset_silent(model)
    else
        JuMP.set_silent(model)
    end

    # Logging solver output.
    if @config(model, optimization.solver.log)
        # todo: replace this with a more general approach
        try
            lcsn = lowercase(JuMP.solver_name(model))
            scenario_name = @config(model, general.name.scenario)
            log_file = abspath(@config(model, paths.results), "$(scenario_name).$(lcsn).log")
            rm(log_file; force=true)
            if JuMP.solver_name(model) == "Gurobi"
                @info "Logging solver output" log_file
                JuMP.set_attribute(model, "LogFile", log_file)
            elseif JuMP.solver_name(model) == "HiGHS"
                @info "Logging solver output" log_file
                JuMP.set_attribute(model, "log_file", log_file)
            else
                # todo: support MOA here
                @error "Logging solver output is currently only supported for Gurobi and HiGHS"
            end
        catch
            @error "Failed to setup solver log file"
        end
    end

    @info "Starting optimize ..."
    JuMP.optimize!(model; kwargs...)

    # todo: make use of `is_solved_and_feasible`? if, make sure the version requirement of JuMP is correct

    if JuMP.result_count(model) == 1
        if JuMP.termination_status(model) == JuMP.MOI.OPTIMAL
            @info "Finished optimizing, solution optimal"
        else
            @error "Finished optimizing, solution non-optimal" status_code = JuMP.termination_status(model) solver_status =
                JuMP.raw_status(model)
        end
    elseif JuMP.result_count(model) == 0
        @error "No results returned after call to `optimize!`. This most likely indicates an infeasible or unbounded model. You can check with `IESopt.compute_IIS(model)` which constraints make your model infeasible. Note: this requires a solver that supports this (e.g. Gurobi)"
        return nothing
    else
        if !isnothing(@config(model, optimization.multiobjective))
            if JuMP.termination_status(model) == JuMP.MOI.OPTIMAL
                @info "Finished optimizing, solution(s) optimal" result_count = JuMP.result_count(model)
            else
                @error "Finished optimizing, solution non-optimal" status_code = JuMP.termination_status(model) solver_status =
                    JuMP.raw_status(model)
            end
        else
            @warn "Unexpected result count after call to `optimize!`" result_count = JuMP.result_count(model) status_code =
                JuMP.termination_status(model) solver_status = JuMP.raw_status(model)
        end
    end

    # Analyse constraint safety results
    if !isempty(internal(model).aux.soft_constraints_penalties)
        relaxed_components = Vector{String}()
        for (k, v) in internal(model).aux.soft_constraints_penalties
            # Skip components that we already know about being relaxed.
            (v.component_name ∈ relaxed_components) && continue

            if JuMP.value(internal(model).aux.soft_constraints_expressions[k]) > 0
                push!(relaxed_components, v.component_name)
            end
        end

        if !isempty(relaxed_components)
            @warn "The safety constraint feature triggered" n_components = length(relaxed_components) components = "[$(relaxed_components[1]), ...]"
            @info "You can further analyse the relaxed components by looking at the `soft_constraints_penalties` and `soft_constraints_expressions` entries in `model.ext`."
        end
    end

    _handle_result_extraction(model)

    # TODO
    # @info "Profiling results after `optimize` [time, top 5]" _profiling_format_top(model, 5)...
    return nothing
end

"""
    function compute_IIS(model::JuMP.Model; filename::String = "")

Compute the IIS and print it. If `filename` is specified it will instead write all constraints to the given file. This
will fail if the solver does not support IIS computation.
"""
function compute_IIS(model::JuMP.Model; filename::String="")
    print = false
    if filename === ""
        print = true
    end

    JuMP.compute_conflict!(model)
    conflict_constraint_list = JuMP.ConstraintRef[]
    for (F, S) in JuMP.list_of_constraint_types(model)
        for con in JuMP.all_constraints(model, F, S)
            if JuMP.MOI.get(model, JuMP.MOI.ConstraintConflictStatus(), con) == JuMP.MOI.IN_CONFLICT
                if print
                    println(con)
                else
                    push!(conflict_constraint_list, con)
                end
            end
        end
    end

    if !print
        io = open(filename, "w") do io
            for con in conflict_constraint_list
                println(io, con)
            end
        end
    end

    return nothing
end

"""
    function get_component(model::JuMP.Model, component_name::AbstractString)

Get the component `component_name` from `model`.
"""
function get_component(model::JuMP.Model, @nospecialize(component_name::AbstractString))
    cn = string(component_name)
    components = internal(model).model.components::Dict{String, _CoreComponent}

    if !haskey(components, cn)
        st = stacktrace()
        trigger = length(st) > 0 ? st[1] : nothing
        origin = length(st) > 1 ? st[2] : nothing
        inside = length(st) > 2 ? st[3] : nothing
        @critical "Trying to access unknown component" component_name = cn trigger origin inside debug =
            _iesopt_debug(model)
    end

    return components[cn]::_CoreComponent
end

"""
    get_components(model::JuMP.Model; tagged::Union{Nothing, String, Vector{String}} = nothing)

Retrieve components from a given IESopt model.

# Arguments
- `model::JuMP.Model`: The IESopt model from which to retrieve components.
- `tagged::Union{Nothing, String, Vector{String}}`: Optional argument to specify tagged components to retrieve. 
  If `nothing`, all components are retrieved. If a `String` or `Vector{String}`, only components with the specified tags are retrieved.

# Returns
- `Vector{_CoreComponent}`: A subset of components from the model.
"""
function get_components(model::JuMP.Model; @nospecialize(tagged::Union{Nothing, String, Vector{String}} = nothing))
    !isnothing(tagged) && return _components_tagged(model, tagged)::Vector{<:_CoreComponent}

    return collect(values(internal(model).model.components))::Vector{<:_CoreComponent}
end

function _components_tagged(model::JuMP.Model, tag::String)
    cnames = get(internal(model).model.tags, tag, String[])
    isempty(cnames) && return _CoreComponent[]
    return get_component.(model, cnames)::Vector{<:_CoreComponent}
end

function _components_tagged(model::JuMP.Model, tags::Vector{String})
    cnames = [get(internal(model).model.tags, tag, String[]) for tag in tags]
    cnames = intersect(cnames...)
    isempty(cnames) && return _CoreComponent[]
    return get_component.(model, cnames)::Vector{<:_CoreComponent}
end

"""
    extract_result(model::JuMP.Model; path::String = "./out", write_to_file::Bool=true)

DEPRECATED
"""
function extract_result(args...)
    @critical "The function `extract_result` is deprecated"
end

"""
    function to_table(model::JuMP.Model; path::String = "./out", write_to_file::Bool=true)

Turn `model` into a set of CSV files containing all core components that represent the model.

This can be useful by running
```julia
IESopt.parse!(model, filename)
IESopt.to_table(model)
```
which will parse the model given by `filename`, without actually building it (which saves a lot of time), and will
output a complete "description" in core components (that are the resolved version of all non-core components).

If `write_to_file` is `false` it will instead return a dictionary of all DataFrames.
"""
function to_table(model::JuMP.Model; path::String="./out", write_to_file::Bool=true)
    tables = Dict(
        Connection => Vector{OrderedDict{Symbol, Any}}(),
        Decision => Vector{OrderedDict{Symbol, Any}}(),
        Node => Vector{OrderedDict{Symbol, Any}}(),
        Profile => Vector{OrderedDict{Symbol, Any}}(),
        Unit => Vector{OrderedDict{Symbol, Any}}(),
    )

    for (id, component) in internal(model).model.components
        push!(tables[typeof(component)], _to_table(component))
    end

    if write_to_file
        for (type, table) in tables
            CSV.write(normpath(@config(model, paths.main), path, "$type.csv"), DataFrames.DataFrame(table))
        end
        return nothing
    end

    return Dict{Type, DataFrames.DataFrame}(type => DataFrames.DataFrame(table) for (type, table) in tables)
end

# This is directly taken from JuMP.jl and exports all internal symbols that do not start with an underscore (roughly).
const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include, :MOI]
for sym in names(@__MODULE__; all=true)
    sym_string = string(sym)
    if sym in _EXCLUDE_SYMBOLS || startswith(sym_string, "_") || startswith(sym_string, "@_")
        continue
    end
    if !(Base.isidentifier(sym) || (startswith(sym_string, "@") && Base.isidentifier(sym_string[2:end])))
        continue
    end
    @eval export $sym
end

RuntimeGeneratedFunctions.init(@__MODULE__)

include("precompile/precompile_traced.jl")
include("precompile/precompile_tools.jl")

end
