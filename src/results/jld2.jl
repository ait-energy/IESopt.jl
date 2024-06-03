function _get_git()
    try
        repo = LibGit2.GitRepo("./")

        if LibGit2.isdirty(repo)
            @warn "The git repository is dirty (you should always commit changes before a run)"
        end

        git_snapshot = LibGit2.snapshot(repo)

        return OrderedDict(
            "branch" => LibGit2.headname(repo),
            "path" => LibGit2.path(repo),
            "commit" => LibGit2.head_oid(repo),
            "snapshot" => OrderedDict(f => getfield(git_snapshot, f) for f in fieldnames(typeof(git_snapshot))),
            "remotes" => OrderedDict(r => LibGit2.url(LibGit2.lookup_remote(repo, r)) for r in LibGit2.remotes(repo)),
        )
    catch error
        @warn "Could not find a valid git repository; consider using git for every model development"
    end

    return OrderedDict{String, Any}()
end

function _get_hash(model::JuMP.Model)
    @error "Hashing is disabled until we decide on which files to include"
    return ""

    # @info "Hashing model description"

    # _hash = SHA.SHA256_CTX()
    # for (root, _, files) in walkdir(_iesopt_config(model).paths.main)
    #     occursin(dirname(_iesopt_config(model).paths.results), root) && continue
    #     for file in files
    #         SHA.update!(_hash, open(read, normpath(root, file)))
    #     end
    # end

    # return bytes2hex(SHA.digest!(_hash))
end

function _get_solver_log(model::JuMP.Model)
    file = abspath(_iesopt_config(model).paths.results, "solver.log")
    isfile(file) || return ""
    return read(file, String)
end

function _get_iesopt_log(model::JuMP.Model)
    try
        file = abspath(replace(string(_iesopt(model).logger.loggers[2].logger.stream.name), "<file " => "", ">" => ""))
        return String(open(read, file))
    catch error
    end

    return ""
end

function _save_results(model::JuMP.Model)
    _iesopt_config(model).results.memory_only && return nothing

    @info "Begin saving results"
    # TODO: support multiple results (from MOA)

    # Make sure the path is valid.
    filepath = normpath(_iesopt_config(model).paths.results, "$(_iesopt_config(model).names.scenario).mfres.jld2")
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

        # file["info/hash"] = @profile _get_hash(model)
        if :git in _iesopt_config(model).results.include
            file["info/git"] = @profile model _get_git()
        end
        if :log in _iesopt_config(model).results.include
            file["info/logs/iesopt"] = _get_iesopt_log(model)
            file["info/logs/solver"] = _get_solver_log(model)
        end

        return nothing
    end

    @info "Results saved to JLD2" file = abspath(filepath)
end

function load_results(filename::String)
    return JLD2.load(filename)
end
