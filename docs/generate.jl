_canonify_string(str::String) = lowercase(replace(str, r"[^a-zA-Z0-9]" => "_"))

function _build_page_paths(entry; parent::String)
    isa(entry, String) && return joinpath(parent, "$(_canonify_string(entry)).md")
    isa(entry, AbstractVector) && return [_build_page_paths(subentry; parent=parent) for subentry in entry]

    isa(entry, Pair) || error("Invalid type of entry in page structure")

    isa(entry.second, String) && return entry.first => "$(_canonify_string(entry.second)).md"

    if isa(entry.second, AbstractVector) && length(entry.second) == 1
        return joinpath(parent, "$(_canonify_string(entry.second[1])).md")
    end

    return entry.first => _build_page_paths(entry.second; parent=joinpath(parent, _canonify_string(entry.first)))
end

# This defines the order of the menu / page structure.
examples_files = [
    file[1:(end - 3)] for
    file in readdir(normpath(@__DIR__, "src", "pages", "user_guide", "examples")) if endswith(file, ".md")
]

_PAGES = _build_page_paths(
    [
        "Home" => "index",
        "Tutorials" => ["setup", "first_model", "next_steps", "results"],
        "User Guide" => [
            "general",
            "Sectors" => ["electricity", "heat", "gas"],
            "solvers",
            "Custom Functionality" => ["templates", "addons"],
            "Examples" => [], # TODO: examples_files,
        ],
        "Manual" => ["yaml", "core_components", "templates", "api"],
        "Developer Documentation" => ["dev_docs"],
        "Changelog" => ["changelog"],
    ];
    parent="pages",
)

# Create `changelog.md` from `CHANGELOG.md`.
include("changelog.jl")
