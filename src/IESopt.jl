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
include("docify/docify.jl")

function _build_model!(model::JuMP.Model)
    @info "[build] Begin creating JuMP formulation from components"

    if @config(model, general.performance.string_names, Bool) != model.set_string_names_on_creation
        new_val = @config(model, general.performance.string_names, Bool)
        @debug "Overwriting `string_names_on_creation` to `$(new_val)` based on config"
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

    # Sort components by their build priority.
    # For instance, Decisions with a default build priority of 1000 are built before all other components
    # with a default build priority of 0.
    # Components with a negative build priority are not built at all.
    corder =
        sort(collect(values(internal(model).model.components)); by=_build_priority, rev=true)::Vector{<:_CoreComponent}

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
                    @info "[build] Invoking addon" addon = name step = addon_fi
                    ret = Base.invokelatest(getfield(prop.addon, addon_fi), model, prop.config)
                    if isnothing(ret)
                        @warn "[build] Please make sure your addon returns `true` or `false` in every step to indicate success/failure" addon =
                            name step = addon_fi
                    elseif ret === false
                        @critical "[build] Addon returned error" addon = name step = addon_fi
                    elseif ret !== true
                        @warn "[build] Addon returned unexpected value: `$(ret)`" addon = name step = addon_fi
                    end
                end
            end
        end
    end

    @debug "[build] Finalizing Virtuals"
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
        @info "[build] Construct and build objective expression `$(name)`"

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
        for term in obj.terms
            JuMP.add_to_expression!(obj.expr, term)
        end
        if !isempty(obj.constants)
            JuMP.add_to_expression!(obj.expr, sum(obj.constants))
        end
    end

    if !_is_multiobjective(model)
        current_objective = @config(model, optimization.objective.current)
        isnothing(current_objective) && @critical "[build] Missing an active objective"
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
    @info "[build > prepare] Run pre-processing checks & initializations"

    # Potentially remove components that are tagged `conditional`, and violate some of their conditions.
    failed_components = []
    for (cname, component) in internal(model).model.components
        !_check(component) && push!(failed_components, cname)
    end
    if length(failed_components) > 0
        @warn "[build > prepare] Some components are removed based on the `conditional` setting" n_components =
            length(failed_components)
        for cname in failed_components
            delete!(internal(model).model.components, cname)
        end
    end

    # Init global addons before preparing components
    if _has_addons(model)
        for (name, prop) in internal(model).input.addons
            if !Base.invokelatest(prop.addon.initialize!, model, prop.config)
                @critical "[build > prepare] Addon failed to set up" name
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

Keyword arguments are passed to the `generate!(...)` function.
"""
function run(filename::String; kwargs...)
    @nospecialize

    model = generate!(filename; kwargs...)

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
function generate!(filename::String; kwargs...)
    @nospecialize

    model = JuMP.Model()::JuMP.Model
    generate!(model, filename; kwargs...)

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
    skip_validation::Bool=_global_settings.skip_validation,
    kwargs...,
)
    @nospecialize

    # local stats_parse, stats_build, stats_total
    # TODO: "re-enable" by refactoring to TimerOutputs

    try
        # Validate before parsing.
        skip_validation || validate(filename) || return nothing

        # Parse & build the model.
        parse!(model, filename; kwargs...) || return model
        with_logger(_iesopt_logger(model)) do
            skip_validation ||
                (@info "[generate] YAML file validation was done; pass `skip_validation = true` to save some time")

            if JuMP.mode(model) != JuMP.DIRECT && JuMP.MOIU.state(JuMP.backend(model)) == JuMP.MOIU.NO_OPTIMIZER
                _attach_optimizer(model)
            end

            return build!(model)
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
            @debug "[generate] Details on error #$(length(_exceptions) + 1)" error = (exception, trace)

            # Error log the backtrace, but remove modules that only clutter the trace.
            trace = [e for e in trace if !isnothing(parentmodule(e)) && !(nameof(parentmodule(e)) in remove_modules)]
            push!(
                _exceptions,
                Symbol(" = = = = = = = = = [ Error #$(length(_exceptions) + 1) ] = = = = = = = =") =>
                    (exception, trace),
            )
        end

        @error "[generate] Error(s) during model generation" debug number_of_errors = length(curr_ex) _exceptions...
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
    solver_name = @config(model, optimization.solver.name)

    @info "[generate > attach] Attaching solver `$(solver_name)` to model"

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
        @critical "[generate > attach] Can't determine proper solver" solver_name
    end

    if @config(model, optimization.solver.mode) == "direct"
        @critical "[generate > attach] Automatic direct mode is currently not supported"
    end

    if solver == :HiGHS
        if _is_multiobjective(model)
            JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(HiGHS.Optimizer))
        else
            JuMP.set_optimizer(model, HiGHS.Optimizer)

            if !haskey(@config(model, optimization.solver.attributes), "ComputeInfeasibilityCertificate")
                @debug "[generate > attach] Default `ComputeInfeasibilityCertificate` to `false` for HiGHS"
                @config(model, optimization.solver.attributes)["ComputeInfeasibilityCertificate"] = false
            end
        end
    else
        try
            @debug "[generate > attach] Trying to import solver interface" solver
            # Main.eval(Meta.parse("import $(solver)"))
            Base.require(Main, solver)
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
        @debug "[generate > attach] Setting MOA mode" mode = moa_mode
        JuMP.set_attribute(model, MOA.Algorithm(), eval(Meta.parse("MOA.$moa_mode()")))
    end

    for (attr, value) in @config(model, optimization.solver.attributes)
        try
            @suppress JuMP.set_attribute(model, attr, value)
            @debug "[generate > attach] Setting attribute" attr value
        catch
            try
                # If the attribute is not a "general" one, try getting it from the solver's interface.
                @suppress JuMP.set_attribute(model, eval(Meta.parse("$(solver).$(attr)()")), value)
                @debug "[generate > attach] Setting attribute" attr value
            catch
                @error "[generate > attach] Failed to set attribute" attr value
            end
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
                @debug "[generate > attach] Setting attribute" attr value
            catch
                @error "[generate > attach] Failed to set attribute" attr value
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
    parameters::Union{Dict, Vector}=_global_settings.parameters,
    config::Dict=_global_settings.config,
    addons::Dict=_global_settings.addons,
    carriers::Dict=_global_settings.carriers,
    components::Dict=_global_settings.components,
    load_components::Dict=_global_settings.load_components,
    virtual_files::Dict{String, DataFrames.DataFrame}=Dict{String, DataFrames.DataFrame}(),
)
    @nospecialize

    if !endswith(filename, ".iesopt.yaml")
        @critical "Model entry config files need to respect the `.iesopt.yaml` file extension" filename
    end

    # Handle passed "modification" keyword arguments.
    model.ext[:_iesopt_kwargs] = Dict(
        :parameters => deepcopy(parameters),
        :config => deepcopy(config),
        :addons => deepcopy(addons),
        :carriers => deepcopy(carriers),
        :components => components,
        :load_components => load_components,
    )

    # TODO: properly check necessity of deepcopy (especially when adding "components" and "load_components")
    isempty(addons) || @error "The `addons` keyword argument is not yet supported"
    isempty(carriers) || @error "The `carriers` keyword argument is not yet supported"
    isempty(load_components) || @error "The `load_components` keyword argument is not yet supported"

    # Load the model specified by `filename`.
    _parse_model!(model, filename) || (@critical "Error while parsing model" filename)

    # Merge virtual files into the model.
    if !isempty(virtual_files)
        with_logger(internal(model).logger) do
            for (fn, df) in virtual_files
                # Get some snapshot config parameters.
                offset = @config(model, optimization.snapshots.offset, Int64)
                aggregation = @config(model, optimization.snapshots.aggregate)

                # Offset and aggregation don't work together.
                if !isnothing(aggregation) && offset != 0
                    @critical "[parse] Snapshot aggregation and non-zero offsets are currently not supported"
                end

                # Get the number of df rows and and the model's snapshot count
                nrows = size(df, 1)
                count = @config(model, optimization.snapshots.count, Int64)

                # Get the range of df rows we want to return.
                # Without snapshot aggregation we can return the rows specified by offset and count.
                # Otherwise, we start at 1 and multiply the number of rows to return by the number of snapshots to aggregate.
                if offset != 0
                    try
                        if !@config(model, optimization.snapshots.offset_virtual_files, Bool)
                            offset = 0
                        end
                    catch
                        @critical "[parse] Missing `optimization.snapshots.offset_virtual_files` when using offset"
                    end
                end
                from, to = isnothing(aggregation) ? (offset + 1, offset + count) : (1, count * (aggregation::Float64))

                # Check if the range of rows is in bounds.
                if from < 1 || to > nrows || from > to
                    @critical "[parse] Trying to access data with out-of-bounds or empty range" filename from to nrows
                end

                internal(model).input.files[fn] = DataFrames.mapcols!(
                    v -> float.(v),
                    df[from:to, :];
                    cols=names(df, Union{Int, Missing}),
                )::DataFrames.DataFrame
            end
            @debug "[parse] Successfully merged $(length(virtual_files)) virtual file(s)"
        end
    end

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
    @invokelatest _prepare_model!(model)

    # Perform conistency checks on all parsed components.
    all_components_ok = true::Bool
    for (id, component) in internal(model).model.components
        all_components_ok &= _isvalid(component)::Bool
    end
    if !all_components_ok
        error("Some components did not pass the consistency check.")
    end

    # Build the model.
    @invokelatest _build_model!(model)

    @info "[build] Model successfully built"

    # @info "Profiling results after `build` [time, top 5]" _profiling_format_top(model, 5)...
    return nothing
end

"""
    write_to_file(model::JuMP.Model, filename::String; format::JuMP.MOI.FileFormats.FileFormat = JuMP.MOI.FileFormats.FORMAT_AUTOMATIC, kwargs...)

Write the given IESopt model to a file with the specified filename and format.

Be aware, that this function will overwrite any existing file with the same name!

# Arguments
- `model::JuMP.Model`: The IESopt model to be written to a file.
- `filename::String`: The name of the file to which the model should be written. Note that if the format is set to
  `FORMAT_AUTOMATIC`, the the file extension will be forced to lower case to allow detection.
- `format::JuMP.MOI.FileFormats.FileFormat` (optional): The format in which the model should be written. The default is
  `JuMP.MOI.FileFormats.FORMAT_AUTOMATIC`; if left as that, it will try to automatically determine the format based on
  the file extension.

All additional keyword arguments are passed to the `JuMP.write_to_file` function.

# Returns
- `String`: The absolute path to the file to which the model was written.

# Example
```julia
import IESopt

model = IESopt.generate!("config.iesopt.yaml")
IESopt.write_to_file(model, "model.lp")
```
"""
function write_to_file(
    model::JuMP.Model,
    filename::String;
    format::JuMP.MOI.FileFormats.FileFormat=JuMP.MOI.FileFormats.FORMAT_AUTOMATIC,
    kwargs...,
)
    if format == JuMP.MOI.FileFormats.FORMAT_AUTOMATIC
        fn, ext = splitext(filename)
        filename = "$(fn)$(lowercase(ext))"
    end

    JuMP.write_to_file(model, filename; format, kwargs...)

    @debug "[write_to_file] Model written to file" filename
    return abspath(filename)
end

"""
    write_to_file(model::JuMP.Model)

Write the given IESopt model to a file for later use. The filename and location is based on the model's scenario name,
and will be written to the general "results" path that is configured.

# Arguments
- `model::JuMP.Model`: The IESopt model to be written to a file.

# Returns
- `String`: The absolute path to the file to which the model was written.

# Example
```julia
import IESopt

model = IESopt.generate!("config.iesopt.yaml")
IESopt.write_to_file(model)
```
"""
function write_to_file(model::JuMP.Model)
    folder = @config(model, paths.results)
    scenario = @config(model, general.name.scenario)

    filename = normpath(folder, "$(scenario).iesopt.mps")
    mkpath(dirname(filename))

    return write_to_file(model, filename)
end

@testitem "write_to_file" tags = [:unittest] begin
    import IESopt.JuMP
    import IESopt.SHA

    check_hash(f, h) =
        open(f, "r") do io
            return true
            # TODO: Files are (YAML?) not deterministic => hashes may change
            # return bytes2hex(SHA.sha1(read(io, String))) == h
        end

    model = generate!(String(Assets.get_path("examples", "01_basic_single_node.iesopt.yaml")))

    comparisons = [
        (fn="test_write_to_file.iesopt.lp", hash="15f3782fa4f38d814d0b247853d4a166c1d7e486"),
        (fn="test_write_to_file.iesopt.LP", hash="15f3782fa4f38d814d0b247853d4a166c1d7e486"),
        (fn="test_write_to_file.lp", hash="15f3782fa4f38d814d0b247853d4a166c1d7e486"),
        (fn="test_write_to_file.iesopt.MPS", hash="2214cbf5df222484d0842043b89f4e5581882f7d"),
    ]

    # Test various file names.
    for c in comparisons
        target = normpath(tempdir(), c.fn)
        file = write_to_file(model, target)
        @test isfile(file)
        @test check_hash(file, c.hash)
        rm(file)
    end

    # Test writing to custom file format (including keeping case).
    file =
        write_to_file(model, normpath(tempdir(), "test_write_to_file.IESOPT"); format=JuMP.MOI.FileFormats.FORMAT_MOF)
    @test isfile(file)
    @test endswith(file, ".IESOPT")
    @test check_hash(file, "789a1df6f7a2fc587f80e590dff4e3a88a4e0e8f")
    rm(file)

    # Test automatically determining the filename.
    file = write_to_file(model)
    @test isfile(file)
    @test check_hash(file, "2214cbf5df222484d0842043b89f4e5581882f7d")
    rm(file)
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
        @warn "[optimize] Relaxing constraints based on soft_constraints"
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

            try
                rm(log_file; force=true)
            catch
                @warn "[optimize] Failed to cleanup solver log file; maybe it appends, maybe it overwrites, maybe it fails - we do not know" log_file
            end

            if JuMP.solver_name(model) == "Gurobi"
                @info "[optimize] Passing model to solver" solver_log_file = log_file
                JuMP.set_attribute(model, "LogFile", log_file)
            elseif JuMP.solver_name(model) == "HiGHS"
                @info "[optimize] Passing model to solver" solver_log_file = log_file
                JuMP.set_attribute(model, "log_file", log_file)
            else
                # todo: support MOA here
                @error "[optimize] Logging solver output is currently only supported for Gurobi and HiGHS"
                @info "[optimize] Passing model to solver"
            end
        catch
            @error "[optimize] Failed to setup solver log file"
            @info "[optimize] Passing model to solver"
        end
    else
        @info "[optimize] Passing model to solver"
    end

    JuMP.optimize!(model; kwargs...)

    # todo: make use of `is_solved_and_feasible`? if, make sure the version requirement of JuMP is correct

    if JuMP.result_count(model) == 1
        if JuMP.termination_status(model) == JuMP.MOI.OPTIMAL
            @info "[optimize] Finished optimizing, solution optimal"
        elseif JuMP.is_solved_and_feasible(model; allow_local=true)
            @warn "[optimize] Finished optimizing, but only a local optimum was found" solver_status =
                JuMP.raw_status(model)
        else
            @error "[optimize] Finished optimizing, a solution is available, but it seems to be non-optimal/infeasible" status_code =
                JuMP.termination_status(model) solver_status = JuMP.raw_status(model)
        end
    elseif JuMP.result_count(model) == 0
        termination_status = JuMP.termination_status(model)
        @error "[optimize] No results returned after call to `optimize!`" termination_status
        if JuMP.termination_status(model) == JuMP.INFEASIBLE
            @info "[optimize] Find out why your model is infeasible by calling `IESopt.compute_IIS(model)`"
        end
        return nothing
    else
        if !isnothing(@config(model, optimization.multiobjective))
            if JuMP.termination_status(model) == JuMP.MOI.OPTIMAL
                @info "[optimize] Finished optimizing, solution(s) optimal" result_count = JuMP.result_count(model)
            elseif JuMP.is_solved_and_feasible(model; allow_local=true)
                @warn "[optimize] Finished optimizing, but only local optima were found" result_count =
                    JuMP.result_count(model) solver_status = JuMP.raw_status(model)
            else
                @error "[optimize] Finished optimizing, solution(s) are available, but seem to be non-optimal/infeasible" result_count =
                    JuMP.result_count(model) status_code = JuMP.termination_status(model) solver_status =
                    JuMP.raw_status(model)
            end
        else
            @warn "[optimize] Unexpected result count after call to `optimize!`" result_count = JuMP.result_count(model) status_code =
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
            @warn "[optimize] The safety constraint feature triggered; you can further analyse the relaxed components by looking at the `soft_constraints_penalties` and `soft_constraints_expressions` entries in `model.ext`." n_components =
                length(relaxed_components) components = "[$(relaxed_components[1]), ...]"
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
    if JuMP.termination_status(model) !== JuMP.INFEASIBLE
        @critical "[compute_IIS] Model status is not `infeasible`; IIS computation is not possible"
        return nothing
    end

    @info "[compute_IIS] Begin computing IIS"
    JuMP.compute_conflict!(model)

    if JuMP.get_attribute(model, JuMP.MOI.ConflictStatus()) !== JuMP.MOI.CONFLICT_FOUND
        @critical "[compute_IIS] Failed to find conflict"
        return nothing
    end

    print = false
    if filename === ""
        print = true
    end

    @info "[compute_IIS] Extracting IIS"
    iis_model, _ = @suppress JuMP.copy_conflict(model)

    conflict_constraint_list = JuMP.ConstraintRef[]
    for (F, S) in JuMP.list_of_constraint_types(iis_model)
        for con in JuMP.all_constraints(iis_model, F, S)
            if print
                println(con)
            else
                push!(conflict_constraint_list, con)
            end
        end
    end

    if !print
        io = open(filename, "w") do io
            for con in conflict_constraint_list
                println(io, con)
            end
        end

        @info "[compute_IIS] IIS written to file" filename
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

# NOTE: Using non-exported internals may break (like for `SpecialFunctions`) since that was never "intended" by
#       package authors.
# @static if @load_preference("precompile_traced", @load_preference("precompile", true))
#     include("precompile/precompile_traced.jl")
# end

@static if @load_preference("precompile_tools", @load_preference("precompile", true))
    include("precompile/precompile_tools.jl")
end

end
