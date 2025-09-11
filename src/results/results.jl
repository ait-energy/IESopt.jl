function _get_git()
    try
        repo = LibGit2.GitRepo("./")

        if LibGit2.isdirty(repo)
            @warn "[optimize > results] The git repository is dirty (you should always commit changes before a run)"
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
        @warn "[optimize > results] Could not find a valid git repository; consider using git for every model development"
    end

    return OrderedDict{String, Any}()
end

function _get_hash(model::JuMP.Model)
    @error "[optimize > results] Hashing is disabled until we decide on which files to include"
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
    lcsn = lowercase(JuMP.solver_name(model))
    scenario_name = @config(model, general.name.scenario)
    log_file = abspath(@config(model, paths.results), "$(scenario_name).$(lcsn).log")
    isfile(log_file) || return ""
    return read(log_file, String)
end

function _get_iesopt_log(model::JuMP.Model)
    try
        file = abspath(replace(string(internal(model).logger.loggers[2].logger.stream.name), "<file " => "", ">" => ""))
        return String(open(read, file))
    catch error
    end

    return ""
end

include("jld2/ResultsJLD2.jl")
include("duckdb/ResultsDuckDB.jl")

function _handle_result_extraction(model::JuMP.Model)
    if @config(model, results.enabled) != :none
        # TODO: include content of result config section
        if !JuMP.is_solved_and_feasible(model)
            @error "[optimize > results] Extracting results is only possible for a solved and feasible model"
        else
            if @config(model, results.backend) == :jld2
                ResultsJLD2._extract_results(model)
                ResultsJLD2._save_results(model)
            elseif @config(model, results.backend) == :duckdb
                db = ResultsDuckDB.extract(model)
                # TODO:
                ResultsDuckDB.close(db)
            end

            @info "[optimize > results] Finished result handling"
        end
    else
        @info "[optimize > results] Skipping result extraction"
    end
end
