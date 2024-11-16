module ResultsJLD2

using ..IESopt: _iesopt, _iesopt_config, _result_fields, _CoreComponent, _CoreComponentResult, _CoreComponentOptResultContainer, _component_type

import LibGit2
import JLD2
import JuMP

include("extract.jl")

function _save_results(model::JuMP.Model)
    _iesopt_config(model).results.memory_only && return nothing

    @info "Begin saving results"
    # TODO: support multiple results (from MOA)

    # Make sure the path is valid.
    filepath =
        normpath(_iesopt_config(model).paths.results, "$(_iesopt_config(model).names.scenario).iesopt.result.jld2")
    mkpath(dirname(filepath))

    # Write results.
    JLD2.jldopen(filepath, "w"; compress=_iesopt_config(model).results.compress) do file
        file["model/components"] = _iesopt(model).results.components
        file["model/objectives"] = _iesopt(model).results.objectives
        file["model/snapshots"] = _iesopt(model).model.snapshots
        file["model/carriers"] = _iesopt(model).model.carriers
        file["model/custom"] = _iesopt(model).results.customs

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

        if :input in _iesopt_config(model).results.include
            file["input/config/toplevel"] = _iesopt(model).input._tl_yaml
            file["input/config/flattened"] = _iesopt(model).aux._flattened_description
            file["input/config/parsed"] = _iesopt(model).input.config
            file["input/parameters"] = _iesopt(model).input.parameters
        end

        # file["info/hash"] = _get_hash(model)
        if :git in _iesopt_config(model).results.include
            file["info/git"] = _get_git()
        end
        if :log in _iesopt_config(model).results.include
            file["info/logs/iesopt"] = _get_iesopt_log(model)
            file["info/logs/solver"] = _get_solver_log(model)
        end

        return nothing
    end

    @info "Results saved to JLD2" file = abspath(filepath)
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
