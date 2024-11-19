function _validate_raw_yamlinternal(filename::String)
    valid = true

    content = Dict{String, Any}()
    try
        merge!(content, YAML.load_file(filename; dicttype=Dict{String, Any}))
    catch
        return _vassert(false, "Could not load YAML file"; filename=filename)
    end

    try
        # Check that mandatory entries in "config" exist.
        valid &= _vassert(haskey(content, "config"), "Top-level config missing mandatory entry"; entry="config")
        config = content["config"]
        valid &= _vassert(
            haskey(config, "optimization"),
            "Top-level config missing mandatory entry";
            entry="config/optimization",
        )
        valid &= _vassert(
            haskey(config["optimization"], "problem_type"),
            "Top-level config missing mandatory entry";
            entry="config/optimization/problem_type",
        )

        # Check carriers
        valid &= _vassert(haskey(content, "carriers"), "Top-level config missing mandatory entry"; entry="carriers")
        carriers = content["carriers"]

        # Check loading of components.
        valid &= _vassert(
            haskey(content, "components") || haskey(content, "load_components"),
            "Top-level config missing mandatory entry";
            entry="at least one of: components, load_components",
        )
        components = get(content, "components", Dict{String, Any}())
        load_components = get(content, "load_components", Vector{String}())

        # Check all components that are directly defined.
        for (k, v) in components
            valid &= _validate_component(k, v)
        end

        # Check multi-objective formulation.
        if haskey(config["optimization"], "multiobjective")
            mo = config["optimization"]["multiobjective"]
            valid &= _vassert(
                occursin("mo", lowercase(config["optimization"]["problem_type"])),
                "Specifying `MO` is mandatory for multi-objective models";
                entry="config/optimization/problem_type",
            )
            valid &= _vassert(
                haskey(mo, "mode"),
                "Top-level config missing mandatory entry";
                entry="config/optimization/multiobjective/mode",
            )
            valid &= _vassert(
                haskey(mo, "terms"),
                "Top-level config missing mandatory entry";
                entry="config/optimization/multiobjective/terms",
            )
            valid &= _vassert(
                haskey(mo, "settings"),
                "Top-level config missing mandatory entry";
                entry="config/optimization/multiobjective/settings",
            )
        else
            valid &= _vassert(
                !occursin("mo", lowercase(config["optimization"]["problem_type"])),
                "Top-level config missing mandatory entry (since `MO` is given in `problem_type`)";
                entry="config/optimization/multiobjective",
            )
        end

        # TODO: Check that only allowed entries exist.
        # TODO: Validate other things.
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; filename=filename, exception=exception)
    end

    return valid
end
