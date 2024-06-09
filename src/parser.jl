function _parse_model!(model::JuMP.Model, filename::String, global_parameters::Dict; verbosity=nothing)
    filename = normpath(filename)
    model.ext[:_iesopt_wd] = dirname(filename)
    model.ext[:_iesopt_verbosity] = verbosity
    model.ext[:iesopt] = _IESoptData(YAML.load_file(filename; dicttype=Dict{String, Any}))

    # Parse the overall global configuration (e.g., replacing parameters).
    (@profile _parse_global_specification!(model, global_parameters)) || return false

    # Construct the final (internal) configuration structure.
    _iesopt(model).input.config = _Config(model)

    # Attach a logger now, so logging can be suppressed/modified for the remaining parsing code.
    _attach_logger!(model)

    with_logger(_iesopt(model).logger) do
        @info "IESopt.jl (core)  |  2021 © AIT Austrian Institute of Technology GmbH" authors = "Stefan Strömer, Daniel Schwabeneder, and contributors" version =
            pkgversion(@__MODULE__) top_level_config = basename(filename) path = abspath(dirname(filename))
        if !isempty(_iesopt(model).input.parameters)
            @info "Global parameters loaded" Dict(Symbol(k) => v for (k, v) in _iesopt(model).input.parameters)...
        end

        # Pre-load all registered files.
        merge!(_iesopt(model).input.files, @profile _parse_inputfiles(model, _iesopt_config(model).files.entries))
        if !isempty(_iesopt(model).input.files)
            @info "Successfully read $(length(_iesopt(model).input.files)) input file(s)"
        end

        description = get(_iesopt(model).input._tl_yaml, "components", Dict{String, Any}())

        # Parse all snapshots.
        @profile _parse_snapshots!(model)

        # Parse all carriers beforehand, since those are used during component parsing.
        @profile _parse_carriers!(model, get(_iesopt(model).input._tl_yaml, "carriers", nothing))

        # Scan for all templates.
        @profile _scan_all_templates(model)

        # Parse potential global addons
        if haskey(_iesopt(model).input._tl_yaml, "addons")
            merge!(
                _iesopt(model).input.addons,
                @profile _parse_global_addons(model, _iesopt(model).input._tl_yaml["addons"])
            )
        end

        # Parse potential external CSV files defining components.
        @profile _parse_components_csv!(model, _iesopt(model).input._tl_yaml, description)

        # Fully flatten the model description before parsing.
        @profile _flatten_model!(model, description)
        merge!(_iesopt(model).aux._flattened_description, deepcopy(description))

        # Construct the objectives container & add all registered objectives.
        for (name, terms) in _iesopt_config(model).optimization.objective.functions
            _iesopt(model).model.objectives[name] =
                (terms=Set{JuMP.AffExpr}(), expr=JuMP.AffExpr(0.0), constants=Vector{Float64}())
            _iesopt(model).aux._obj_terms[name] = terms
        end

        # Parse all components into a unified storage and keep a reference of "name=>id" matchings.
        return (@profile _parse_components!(model, description))

        # Construct the dictionary that holds all constraints that wish to be relaxed. These include (as value)
        # their respective penalty. This exists, even if the model constraint_safety setting is off, since individual
        # could choose to use it separately.
        # -> this is already done when creating the IESopt internal data structure.

        @info "Profiling results after `parse` [time, top 5]" _profiling_format_top(model, 5)...
    end

    return true
end

function _parse_global_specification!(model::JuMP.Model, global_parameters::Dict)
    data = _iesopt(model).input._tl_yaml

    # Check for stochastic configurations.
    if haskey(data, "stochastic")
        _iesopt(model).input.stochastic[:base_config] = data["stochastic"]
        _iesopt(model).input.stochastic[:scenario] = Dict()

        if isempty(global_parameters)
            @warn "Missing global parameters in stochastic model; you can safely ignore this warning if this is a stochastic main-problem"
        else
            for stochastic_param in keys(_iesopt(model).input.stochastic[:base_config]["parameters"])
                if haskey(global_parameters, stochastic_param)
                    _iesopt(model).input.stochastic[:scenario][stochastic_param] = global_parameters[stochastic_param]
                else
                    @warn "Missing stochastic parameter; you can safely ignore this warning if this is a stochastic main-problem" stochastic_param
                end
            end
        end

        if isempty(_iesopt(model).input.stochastic[:scenario])
            # No parameters registered. If this is a main model we need to supply a reasonable default to allow full
            # parsing of the config file. If not there is something wrong.
            @warn "Guessing defaults for stochastic parameter; you can safely ignore this warning if this is a stochastic main-problem"
            for (stoch_param, entries) in _iesopt(model).input.stochastic[:base_config]["parameters"]
                _iesopt(model).input.stochastic[:scenario][stoch_param] = entries[1]
                @info "Guessing stochastic parameter" stoch_param value = entries[1]
            end
        end
    end

    # Check if there are global parameters that need replacement.
    if haskey(data, "parameters") ||
       (!isempty(_iesopt(model).input.stochastic) && !isempty(_iesopt(model).input.stochastic[:scenario]))
        # Pop out parameters.
        parameters = pop!(data, "parameters", Dict())

        if parameters isa String
            parameters = YAML.load_file(normpath(model.ext[:_iesopt_wd], parameters); dicttype=Dict{String, Any})
        elseif parameters isa Dict
        else
            @critical "Unrecognized format for global parameters" type = typeof(parameters)
        end

        if !isempty(_iesopt(model).input.stochastic)
            # Inject stochastic parameters.
            for (key, value) in _iesopt(model).input.stochastic[:scenario]
                if haskey(parameters, key)
                    @critical "Parameter name collision while trying to inject stochastic parameter" stoch_param = key
                end
                parameters[key] = value
            end
        end

        # Replace default values from `global_parameters`.
        for (param, value) in parameters
            parameters[param] = pop!(global_parameters, param, value)
            isnothing(parameters[param]) && (@critical "Mandatory parameter missing value" parameter = param)
        end

        # Report unused global parameters.
        for (attr, _) in global_parameters
            @warn "Parameter supplied but not used in model specification" parameter = attr
        end

        # Construct the parsed global configuration with all parameter replacements.
        replacements = Regex(join(["<$k>" for k in keys(parameters)], "|"))
        _iesopt(model).input._tl_yaml = YAML.load(
            replace(
                replace(YAML.write(data), replacements => p -> parameters[p[2:(end - 1)]]),
                "\"" => "",  # this is necessary to prevent `Number`s being enclosed with "", ending up as `String`
                "nothing" => "null", # this is necessary to properly preserve "null" (as nothing)
            );
            dicttype=Dict{String, Any},
        )

        merge!(_iesopt(model).input.parameters, parameters)
    else
        if !isempty(global_parameters)
            @warn "Global parameters passed to IESopt, but none defined in model config"
        end
    end

    return true
end

function _parse_global_addons(model::JuMP.Model, addons::Dict{String, Any})
    @info "Preloading global addons"
    return Dict{String, NamedTuple}(
        filename => (addon=_getfile(model, string(filename, ".jl")), config=prop) for (filename, prop) in addons
    )
end

function _parse_inputfiles(model::JuMP.Model, files::Dict{String, String})
    isempty(files) || @info "Detected input files: Start preloading"
    return Dict{String, Union{DataFrames.DataFrame, Module}}(
        name => _getfile(model, filename) for (name, filename) in files
    )
end

function _flatten_model!(model::JuMP.Model, description::Dict{String, Any})
    @info "Begin flattening model"

    cnt_disabled_components = 0
    toflatten::Vector{String} = collect(keys(description))

    while length(toflatten) > 0
        cname = pop!(toflatten)

        # Skip a component if it is "disabled" (since we are still in the top-level).
        if _parse_bool(model, get(description[cname], "disabled", false)) ||
           !_parse_bool(model, pop!(description[cname], "enabled", true))
            delete!(description, cname)
            cnt_disabled_components += 1
            continue
        end

        type = description[cname]["type"]

        if type == "Expression"
            @critical "The `Expression` Core Component is deprecated" component = cname
        end

        # Skip core components.
        (type in ["Node", "Connection", "Profile", "Unit", "Decision"]) && continue

        _is_valid_template_name(type) || @error "Invalid type of `Template` (check documentation)" type

        # Try parsing it.
        new_components = _parse_noncore!(model, description, cname)
        toflatten = vcat(toflatten, new_components)
    end

    @info "Finished flattening model" number_of_disabled_components = cnt_disabled_components
end

function _validate(data::Dict; schema::String="")
    @warn "Validation is currently not updated to new YAML syntax and will therefore be skipped"
    return nothing
end

function _parse_components!(model::JuMP.Model, description::Dict{String, Any})
    @info "Parsing components from YAML" n_components = length(description)

    components = _iesopt(model).model.components
    type_info = Dict(t => 0 for t in ["Connection", "Decision", "Node", "Profile", "Unit"])

    for (desc, prop) in description
        if _parse_bool(model, pop!(prop, "disabled", false)) || !_parse_bool(model, pop!(prop, "enabled", true))
            @critical "Disabled components should not end up in parse"
        end

        type = pop!(prop, "type")
        type_info[type] += 1
        name = desc

        # Place name of current attempted parse into `debug`.
        _iesopt(model).debug = name

        # Calculate constraint safety settings. Those default to the model-wide settings.
        constraint_safety = pop!(prop, "constraint_safety", _iesopt_config(model).optimization.constraint_safety)
        constraint_safety_cost =
            pop!(prop, "constraint_safety_cost", _iesopt_config(model).optimization.constraint_safety_cost)

        # Drop auxiliary columns (starting with `$`) that are only used by external tools.
        for k in keys(prop)
            (k[1] == '$') && delete!(prop, k)
        end

        if haskey(prop, "objectives")
            for (obj, term) in pop!(prop, "objectives")
                if !haskey(_iesopt(model).aux._obj_terms, obj)
                    @critical "Objective not found in `objectives` definition" objective = obj component = name
                end
                _add_obj_term!(model, term; component=name, objective=obj)
            end
        end

        if type == "Node"
            # Extract and convert the Carrier (possible since it is mandatory).
            carrier = _iesopt(model).model.carriers[pop!(prop, "carrier")]

            # Convert to _Expression.
            state_lb = _convert_to_expression(model, pop!(prop, "state_lb", nothing))
            state_ub = _convert_to_expression(model, pop!(prop, "state_ub", nothing))

            # Convert to Symbol
            state_cyclic = Symbol(pop!(prop, "state_cyclic", :eq))
            nodal_balance = Symbol(pop!(prop, "nodal_balance", :enforce))

            components[name] = Node(;
                model=model,
                name=name,
                carrier=carrier,
                constraint_safety=constraint_safety,
                constraint_safety_cost=constraint_safety_cost,
                state_lb=state_lb,
                state_ub=state_ub,
                state_cyclic=state_cyclic,
                nodal_balance=nodal_balance,
                Dict(Symbol(k) => v for (k, v) in prop)...,
            )
        elseif type == "Connection"
            # Handle optional carrier.
            carrier = pop!(prop, "carrier", nothing)

            node_from_carrier = if haskey(components, prop["node_from"])
                components[prop["node_from"]].carrier.name
            else
                description[prop["node_from"]]["carrier"]
            end

            node_to_carrier = if haskey(components, prop["node_to"])
                components[prop["node_to"]].carrier.name
            else
                description[prop["node_to"]]["carrier"]
            end

            if node_from_carrier != node_to_carrier
                @critical "Carrier mismatch in Connection, connecting wrong Nodes" component = name
            end

            if isnothing(carrier)
                carrier = _iesopt(model).model.carriers[node_from_carrier]
            else
                if node_from_carrier != carrier
                    @critical "Carrier mismatch in Connection, wrong Carrier given" component = name
                end
                @info "Specifying `carrier` in Connection is not necessary" maxlog = 1
                carrier = _iesopt(model).model.carriers[carrier]
            end

            # Convert to _Expression.
            lb = _convert_to_expression(model, pop!(prop, "lb", nothing))
            ub = _convert_to_expression(model, pop!(prop, "ub", nothing))
            capacity = _convert_to_expression(model, pop!(prop, "capacity", nothing))
            cost = _convert_to_expression(model, pop!(prop, "cost", nothing))
            loss = _convert_to_expression(model, pop!(prop, "loss", nothing))

            # Initialize.
            components[name] = Connection(;
                model=model,
                name=name,
                constraint_safety=constraint_safety,
                constraint_safety_cost=constraint_safety_cost,
                carrier=carrier,
                lb=lb,
                ub=ub,
                capacity=capacity,
                cost=cost,
                loss=loss,
                Dict(Symbol(k) => v for (k, v) in prop)...,
            )
        elseif type == "Profile"
            # Extract and convert the Carrier (possible since it is mandatory).
            carrier = _iesopt(model).model.carriers[pop!(prop, "carrier")]

            # Convert to _Expression.
            value = _convert_to_expression(model, pop!(prop, "value", nothing))
            lb = _convert_to_expression(model, pop!(prop, "lb", nothing))
            ub = _convert_to_expression(model, pop!(prop, "ub", nothing))
            cost = _convert_to_expression(model, pop!(prop, "cost", nothing))

            # Convert to Symbol
            mode = Symbol(pop!(prop, "mode", :fixed))
            allow_deviation = Symbol(pop!(prop, "allow_deviation", :off))

            # Initialize.
            components[name] = Profile(;
                model=model,
                name=name,
                carrier=carrier,
                constraint_safety=constraint_safety,
                constraint_safety_cost=constraint_safety_cost,
                value=value,
                mode=mode,
                lb=lb,
                ub=ub,
                cost=cost,
                allow_deviation=allow_deviation,
                Dict(Symbol(k) => v for (k, v) in prop)...,
            )
        elseif type == "Unit"
            # Convert strings that contain an `_Expression`.

            # The capacity is mandatory.
            capacity_str = pop!(prop, "capacity")
            if !(capacity_str isa AbstractString) || (!occursin("in:", capacity_str) && !occursin("out:", capacity_str))
                @critical "`capacity` must be specified with either `out:carrier` or `in:carrier`" unit = name
            end
            _capacity, _capacity_port = rsplit(capacity_str, " "; limit=2)
            _capacity_inout, _capacity_carrier = split(_capacity_port, ":")
            capacity_carrier = (inout=Symbol(_capacity_inout), carrier=_iesopt(model).model.carriers[_capacity_carrier])

            # The marginal cost not.
            if haskey(prop, "marginal_cost")
                marginal_cost_str = pop!(prop, "marginal_cost")
                if !occursin("in:", marginal_cost_str) && !occursin("out:", marginal_cost_str)
                    @critical "`marginal_cost` must be specified with either `out:carrier` or `in:carrier`" unit = name
                end
                _marginal_cost, _marginal_cost_port = strip.(rsplit(marginal_cost_str, "per"; limit=2))
                _marginal_cost_inout, _marginal_cost_carrier = split(_marginal_cost_port, ":")
                marginal_cost_carrier =
                    (inout=Symbol(_marginal_cost_inout), carrier=_iesopt(model).model.carriers[_marginal_cost_carrier])
            else
                _marginal_cost = nothing
                marginal_cost_carrier = nothing
            end

            # Convert to _Expression.
            availability = _convert_to_expression(model, pop!(prop, "availability", nothing))
            availability_factor = _convert_to_expression(model, pop!(prop, "availability_factor", nothing))
            unit_count = _convert_to_expression(model, pop!(prop, "unit_count", 1))
            capacity = _convert_to_expression(model, _capacity)
            marginal_cost = _convert_to_expression(model, _marginal_cost)

            # Convert to Symbol
            unit_commitment = Symbol(pop!(prop, "unit_commitment", :off))

            # Convert to carriers.
            carriers = _iesopt(model).model.carriers
            inputs = Dict{Carrier, String}(carriers[k] => v for (k, v) in pop!(prop, "inputs", Dict()))
            outputs = Dict{Carrier, String}(carriers[k] => v for (k, v) in pop!(prop, "outputs", Dict()))

            # Initialize.
            components[name] = Unit(;
                model=model,
                name=name,
                constraint_safety=constraint_safety,
                constraint_safety_cost=constraint_safety_cost,
                inputs=inputs,
                outputs=outputs,
                availability=availability,
                availability_factor=availability_factor,
                unit_count=unit_count,
                capacity=capacity,
                marginal_cost=marginal_cost,
                unit_commitment=unit_commitment,
                capacity_carrier=capacity_carrier,
                marginal_cost_carrier=marginal_cost_carrier,
                Dict(Symbol(k) => v for (k, v) in prop)...,
            )
        elseif type == "Decision"
            # Convert to Symbol
            mode = Symbol(pop!(prop, "mode", :linear))

            lb = pop!(prop, "lb", 0)
            ub = pop!(prop, "ub", nothing)
            cost = pop!(prop, "cost", nothing)

            (lb isa AbstractString) && (lb = eval(Meta.parse(lb)))
            (ub isa AbstractString) && (ub = eval(Meta.parse(ub)))
            (cost isa AbstractString) && (cost = eval(Meta.parse(cost)))

            # Initialize.
            components[name] = Decision(;
                model=model,
                name=name,
                constraint_safety=constraint_safety,
                constraint_safety_cost=constraint_safety_cost,
                mode=mode,
                lb=lb,
                ub=ub,
                cost=cost,
                Dict(Symbol(k) => v for (k, v) in prop)...,
            )
            # elseif type == "Expression"
            #     parametric = pop!(prop, "parametric", _iesopt_config(model).parametric_expressions)
            #     components[current_id] = Expression(;
            #         model=model,
            #         id=current_id,
            #         name=name,
            #         constraint_safety=constraint_safety,
            #         constraint_safety_cost=constraint_safety_cost,
            #         parametric=parametric,
            #         Dict(Symbol(k) => v for (k, v) in prop)...,
            #     )
        else
            error("Non core components cannot be constructed.")
        end
    end

    @info "Finished parsing components" n = length(components) connections = type_info["Connection"] decisions =
        type_info["Decision"] nodes = type_info["Node"] profiles = type_info["Profile"] units = type_info["Unit"]

    return _iesopt(model).debug = "parse complete"
end

function _parse_components_csv!(
    model::JuMP.Model,
    data::Dict{String, Any},
    description::Dict{String, Any};
    path::Union{String, Nothing}=nothing,
)
    !haskey(data, "load_components") && return

    # Prepare path.
    path = isnothing(path) ? _iesopt_config(model).paths.components : path

    # Get all files, including a potential recursive search using regexp.
    files_to_load = []
    for entry in data["load_components"]
        if entry == ".csv"
            length(data["load_components"]) == 1 ||
                @critical "Using `.csv` in `load_components` is only allowed as sole entry"
            for (root, dirs, files) in walkdir(path)
                for file in files
                    endswith(file, ".csv") || continue
                    push!(files_to_load, normpath(relpath(root, path), file))
                end
            end
        elseif endswith(entry, ".csv")
            push!(files_to_load, normpath(entry))
        elseif endswith(entry, ".xlsx")
            @critical "Excel files are not supported for component definitions" file = entry
        else
            # Example:
            # Match all files in the `thermals/install` directory, except `biomass.csv`.
            #       "^thermals/install/((?!biomass\.csv$).)*\.csv$"
            for (root, dirs, files) in walkdir(path)
                for file in files
                    isnothing(match(Regex(entry), normpath(relpath(root, path), file))) && continue
                    push!(files_to_load, normpath(relpath(root, path), file))
                end
            end
        end
    end

    warnlogcount = 0
    for file in files_to_load
        df = _getfile(model, file; path=:components, slice=false)

        # todo: this is probably super inefficient
        for row in eachrow(df)
            name = row.name
            _is_valid_component_name(name) || @error "Invalid name for component (check documentation)" name

            if haskey(description, name)
                @critical "Duplicate component entry detected" file component = name
            end
            props = row[DataFrames.Not(:name)]

            dict_entries = Vector{String}()
            sizehint!(dict_entries, length(props))
            for (k, v) in zip(names(props), values(props))
                if !ismissing(v)
                    if !isnothing(_iesopt(model).input.parameters) && v[1] == '<'
                        # This is a parameter that we need to replace.
                        push!(dict_entries, "$k: $(_iesopt(model).input.parameters[v[2:(end - 1)]])")
                    else
                        push!(dict_entries, "$k: $v")
                    end
                else
                    # Is this a global parameter that we should fill in automatically?
                    if !isnothing(_iesopt(model).input.parameters) && haskey(_iesopt(model).input.parameters, k)
                        if warnlogcount == 0
                            @warn "You left a field empty in a CSV component defintion file that corresponds to a global parameter. Automatic replacement is happening. Did you really intend this?" component =
                                name property = k
                            warnlogcount += 1
                        end
                        push!(dict_entries, "$k: $(_iesopt(model).input.parameters[k])")
                    end

                    # We skip values that are "just missing".
                end
            end

            description[name] = YAML.load(join(dict_entries, "\n"); dicttype=Dict{String, Any})
        end
    end
end
