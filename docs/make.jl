const is_local_draft = "running_local_liveserver" in ARGS
const running_in_ci = haskey(ENV, "CI") || haskey(ENV, "GITHUB_ACTIONS")
const PATH_DOCS_SRC = normpath(@__DIR__, "src")
const PATH_DOCS_PAGES = normpath(PATH_DOCS_SRC, "pages")

if is_local_draft
    try
        import Revise
        Revise.revise()
    catch
        @warn "Building documentation without Revise support. If you want to automatically refresh docstrings from within IESopt.jl, you need Revise installed."
    end
end

using IESopt
using Documenter

# Set up, and generate everything as needed.
include("generate.jl")

# Build documentation.
makedocs(;
    sitename="-- IESopt --",
    authors="Stefan Strömer (@sstroemer), Daniel Schwabeneder (@daschw), and contributors",
    format=Documenter.HTML(;
        canonical="https://ait-energy.github.io/IESopt.jl",
        edit_link="dev",
        prettyurls=true,
        collapselevel=2,
        mathengine=Documenter.MathJax2(),
        highlights=["yaml", "python"],
        assets=[asset("assets/base_template.css"; class=:css, islocal=true)],
        size_threshold=300_000,
        size_threshold_warn=200_000,
    ),
    # modules=[IESopt],
    pages=_PAGES,
    doctest=false,
    pagesonly=true,
    warnonly=true,
    draft=is_local_draft,
)

# Deploy documentation, if we are not running locally.
if !is_local_draft
    deploydocs(;
        repo="github.com/ait-energy/IESopt.jl",
        push_preview=true,      # previews for PRs (not from forks)
        versions=[
            "stable" => "v^",   # "stable" => latest version
            "v#.#",             # include all minor versions
            "dev" => "dev",
            # "v#.#.#",         # use this to include all released versions
            # "v1.1.6",         # use this to include a specific version
        ],
    )
end
