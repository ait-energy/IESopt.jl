"""
    ResultsJLD2

This module provides functions to save and load results to and from JLD2 files.
"""
module ResultsJLD2

using ..IESopt:
    internal,
    @config,
    _result_fields,
    _CoreComponent,
    _CoreComponentResult,
    _CoreComponentOptResultContainer,
    _component_type,
    _get_git,
    _get_iesopt_log,
    _get_solver_log

import LibGit2
import JLD2
import JuMP

include("extract.jl")

function _save_results(model::JuMP.Model)
    @config(model, results.memory_only) && return nothing

    # TODO: support multiple results (from MOA)

    # Make sure the path is valid.
    scenario_name = @config(model, general.name.scenario)
    filepath = normpath(@config(model, paths.results), "$(scenario_name).iesopt.result.jld2")
    mkpath(dirname(filepath))

    @info "[optimize > results > JLD2] Begin saving results" file = abspath(filepath)

    # Write results.
    JLD2.jldopen(filepath, "w"; compress=@config(model, results.compress)) do file
        file["model/components"] = internal(model).results.components
        file["model/objectives"] = internal(model).results.objectives
        file["model/snapshots"] = internal(model).model.snapshots
        file["model/carriers"] = internal(model).model.carriers
        file["model/custom"] = internal(model).results.customs

        file["attributes/iesopt_version"] = string(pkgversion(@__MODULE__))
        file["attributes/solver_name"] = JuMP.solver_name(model)
        file["attributes/termination_status"] = string(JuMP.termination_status(model))
        file["attributes/solver_status"] = string(JuMP.raw_status(model))
        file["attributes/result_count"] = JuMP.result_count(model)
        file["attributes/objective_value"] = JuMP.objective_value(model)
        file["attributes/solve_time"] = JuMP.solve_time(model)
        file["attributes/has_duals"] = JuMP.has_duals(model)
        file["attributes/primal_status"] = Int(JuMP.primal_status(model))
        file["attributes/dual_status"] = Int(JuMP.dual_status(model))

        if :input in @config(model, results.include)
            file["input/config/toplevel"] = internal(model).input._tl_yaml
            file["input/config/flattened"] = internal(model).aux._flattened_description
            file["input/config/parsed"] = internal(model).input.config
            file["input/parameters"] = internal(model).input.parameters
        end

        # file["info/hash"] = _get_hash(model)
        if :git in @config(model, results.include)
            file["info/git"] = _get_git()
        end

        if :log in @config(model, results.include)
            file["info/logs/iesopt"] = _get_iesopt_log(model)
            file["info/logs/solver"] = _get_solver_log(model)
        end

        return nothing
    end
end

"""
    load_results(filename::String)

Load results from a JLD2 file.

# Arguments
- `filename::String`: The path to the JLD2 file.

# Returns
- `results`: The IESopt result object.
"""
function load_results(filename::String)
    return JLD2.load(filename)
end

export _extract_results, _save_results, load_results

end
