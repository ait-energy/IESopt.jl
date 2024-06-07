"""
    pack(file::String; out::String="", method=:store)

Packs the IESopt model specified by the top-level config file `file` into single file.

The `out` argument specifies the output file name. If not specified, a temporary file is created. Returns the output
file name. The `method` argument specifies the compression method to use. The default is `:store`, which means no
compression is used. The other option is `:deflate`, which uses the DEFLATE compression method. The default (`:auto`)
applies `:store` to all files below 1 MB, `:deflate` otherwise.
"""
function pack(file::String; out::String="", method::Symbol=:auto, include_results::Bool=false)
    root_path = dirname(normpath(file))

    zipfile_method = method == :store ? ZipFile.Store : ZipFile.Deflate
    zipfile_name = normpath(isempty(out) ? tempname() : normpath(root_path, out))
    if count(==('.'), zipfile_name) > 1
        @error "Output filename contains invalid special characters (`.`), which can lead to errors" zipfile_name
        zipfile_name = split(zipfile_name, "."; limit=2)[1] * ".iesopt"
    else
        zipfile_name = rsplit(zipfile_name, "."; limit=2)[1] * ".iesopt"
    end

    toplevel_config = YAML.load_file(file; dicttype=OrderedDict{String, Any})

    paths = []
    if haskey(toplevel_config["config"], "paths")
        paths_dict = toplevel_config["config"]["paths"]
        for entry in ["files", "templates", "components", "addons", "results"]
            haskey(paths_dict, entry) && push!(paths, abspath(root_path, paths_dict[entry]))
        end
    end

    toplevel_config_relname = relpath(file, root_path)
    info = Dict(
        "version" => string(pkgversion(@__MODULE__)),
        "config" => toplevel_config_relname,
        "files" => Dict{String, Vector{String}}(
            "configs" => Vector{String}(),
            "parameters" => Vector{String}(),
            "data" => Vector{String}(),
            "addons" => Vector{String}(),
            "templates" => Vector{String}(),
            "results" => Vector{String}(),
        ),
    )

    files = Set()
    push!(files, toplevel_config_relname)
    haskey(toplevel_config, "supplemental") && push!(files, toplevel_config["supplemental"])

    n_files_skipped = 0
    n_files_valid = 0
    for (root, _, filenames) in walkdir(root_path)
        for filename in filenames
            if endswith(filename, ".iesopt.yaml")
                if relpath(normpath(root, filename), root_path) == filename
                    push!(files, relpath(normpath(root, filename), root_path))
                    push!(info["files"]["configs"], relpath(normpath(root, filename), root_path))
                else
                    @warn "Encountered \"top-level config\" file outside top-level directory, skipping" filename
                    n_files_skipped += 1
                end
                continue
            end

            if !startswith(abspath(root, filename), Regex(join(paths, "|")))
                @debug "NOT packing file" file = normpath(root, filename)
                n_files_skipped += 1
                continue
            end

            if endswith(filename, ".csv")
                push!(files, relpath(normpath(root, filename), root_path))
                push!(info["files"]["data"], relpath(normpath(root, filename), root_path))
            elseif endswith(filename, ".jl")
                push!(files, relpath(normpath(root, filename), root_path))
                push!(info["files"]["addons"], relpath(normpath(root, filename), root_path))
            elseif endswith(filename, ".iesopt.template.yaml")
                push!(files, relpath(normpath(root, filename), root_path))
                push!(info["files"]["templates"], relpath(normpath(root, filename), root_path))
            elseif endswith(filename, ".iesopt.param.yaml")
                push!(files, relpath(normpath(root, filename), root_path))
                push!(info["files"]["parameters"], relpath(normpath(root, filename), root_path))
            elseif endswith(filename, ".iesopt.result.jld2") && include_results
                push!(files, relpath(normpath(root, filename), root_path))
                push!(info["files"]["results"], relpath(normpath(root, filename), root_path))
            else
                @debug "NOT packing file" file = normpath(root, filename)
                n_files_skipped += 1
                continue
            end

            @debug "Packing file" file = normpath(root, filename)
            n_files_valid += 1
        end
    end

    zipfile = ZipFile.Writer(zipfile_name)
    write(ZipFile.addfile(zipfile, "__info__"; method=zipfile_method), JSON.json(info))
    for file in files
        filepath = normpath(root_path, file)
        zm = (zipfile_method == :auto) ? ((filesize(filepath) < 1e6) ? :store : :deflate) : zipfile_method

        open(filepath, "r") do f
            return write(ZipFile.addfile(zipfile, file; method=zm), read(f))
        end
    end
    close(zipfile)

    @info "Successfully packed model description" output_file = zipfile_name packed_files = n_files_valid skipped_files =
        n_files_skipped

    return zipfile_name
end

"""
    unpack(file::String; out::String="", force_overwrite::Bool=false)

Unpacks the IESopt model specified by `file`.

The `out` argument specifies the output directory. If not specified, a temporary directory is created. Returns the
path to the top-level config file. The `force_overwrite` argument specifies whether to overwrite existing files.
"""
function unpack(file::String; out::String="", force_overwrite::Bool=false)
    output_path = isempty(out) ? tempname() : mkpath(abspath(out))
    file = abspath(file)

    info = nothing
    n_skipped = 0
    n_written = 0

    zarchive = ZipFile.Reader(file)
    for file in zarchive.files
        if endswith(file.name, "__info__")
            info = JSON.parse(read(file, String))
            continue
        end

        filepath = normpath(output_path, file.name)

        if isfile(filepath) && !force_overwrite
            n_skipped += 1
            continue
        end

        mkpath(dirname(filepath))
        write(filepath, read(file))
        n_written += 1
    end
    close(zarchive)

    if string(pkgversion(@__MODULE__)) != info["version"]
        @warn "You are trying to unpack an IESopt model that was created using a different version, which may not be compatible" detected =
            info["version"] active = string(pkgversion(@__MODULE__))
    end

    info["config"] = normpath(output_path, info["config"])
    if n_skipped > 0
        @warn "Skipped $(n_skipped)/$(n_skipped + n_written) files; use `force_overwrite=true` to overwrite existing files" config =
            info["config"] files_written = n_written
    else
        @info "Unpacked model description" config = info["config"] files_written = n_written
    end

    return info
end

# function pack(filename::String; out::String="")
#     if isempty(out)
#         out = tempname()
#     end

#     root_path = dirname(normpath(filename))
#     toplevel_config = YAML.load_file(filename; dicttype=OrderedDict{String, Any})

#     paths = []
#     if haskey(toplevel_config["config"], "paths")
#         paths_dict = toplevel_config["config"]["paths"]
#         for entry in ["files", "templates", "components", "addons"]
#             haskey(paths_dict, entry) && push!(paths, abspath(root_path, paths_dict[entry]))
#         end
#     end

#     files = Set()
#     haskey(toplevel_config, "parameters") && push!(files, toplevel_config["parameters"])
#     haskey(toplevel_config, "supplemental") && push!(files, toplevel_config["supplemental"])
#     for (root, _, filenames) in walkdir(root_path)
#         for filename in filenames
#             startswith(abspath(root, filename), Regex(join(paths, "|"))) || continue
#             if endswith(filename, ".csv") || endswith(filename, ".iesopt.template.yaml") || endswith(filename, ".jl")
#                 filepath = normpath(root, filename)
#                 push!(files, relpath(filepath, root_path))
#             end
#         end
#     end
#     files = collect(files)

#     nc = NCDatasets.NCDataset(
#         out,
#         "c";
#         attrib=OrderedDict("tlc_filename" => splitdir(filename)[2], "tlc_content" => read(filename)),
#     )

#     grp_files = NCDatasets.defGroup(nc, "files")

#     for i in eachindex(files)
#         file = files[i]
#         if endswith(file, ".csv")
#             df =
#                 (CSV.File(
#                     normpath(root_path, file);
#                     stringtype=String,
#                     typemap=Dict(Bool => String, Int64 => Float64),
#                 )) |> DataFrames.DataFrame
#             cols = names(df)

#             for j in eachindex(cols)
#                 value = collect(df[!, cols[j]])
#                 value_type = string(eltype(value))
#                 if occursin("String", value_type)
#                     fill_value = ""
#                 elseif occursin("Float", value_type)
#                     fill_value = NaN
#                 else
#                     @error "Unexpected type in CSV file" file value_type
#                 end
#                 NCDatasets.defVar(
#                     grp_files,
#                     "file_$(i)_col_$(j)",
#                     value,
#                     ("row_$(i)",);
#                     attrib=OrderedDict(
#                         "filename" => file,
#                         "type" => "csv",
#                         "column_name" => cols[j],
#                         "_FillValue" => fill_value,
#                     ),
#                 )
#             end
#         elseif endswith(file, ".yaml")
#             byte_data = read(normpath(root_path, file))
#             NCDatasets.defVar(
#                 grp_files,
#                 "file_$(i)",
#                 byte_data,
#                 ("byte_$(i)",);
#                 attrib=OrderedDict("filename" => file, "type" => split("files/25/global.iesopt.param.yaml", ".")[end - 1]),
#             )
#         elseif endswith(file, ".jl")
#             byte_data = read(normpath(root_path, file))
#             NCDatasets.defVar(
#                 grp_files,
#                 "file_$(i)",
#                 byte_data,
#                 ("byte_$(i)",);
#                 attrib=OrderedDict("filename" => file, "type" => "jl"),
#             )
#         end
#     end

#     close(nc)

#     return out
# end
