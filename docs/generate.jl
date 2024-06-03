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

# Scan publication and project references.
_REF_PUBL = [
    joinpath("pages", "references", "publications", "entries", f) for
    f in readdir(normpath(@__DIR__, "src", "pages", "references", "publications", "entries"))
]
_REF_PROJ = [
    joinpath("pages", "references", "projects", "entries", f) for
    f in readdir(normpath(@__DIR__, "src", "pages", "references", "projects", "entries"))
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
        "References" => ["Publications" => ["index", "__placeholder__"], "Projects" => ["index", "__placeholder__"]],
        "Developer Documentation" => ["dev_docs"],
        "Changelog" => ["changelog"],
    ];
    parent="pages",
)

# Manually add in publication and project references.
_references = first(p for p in _PAGES if p.first == "References").second
pop!(_references[1].second)
pop!(_references[2].second)
append!(_references[1].second, _REF_PUBL)
append!(_references[2].second, _REF_PROJ)

# Create `changelog.md` from `CHANGELOG.md`.
include("changelog.jl")
