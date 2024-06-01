using IESopt
using Documenter

DocMeta.setdocmeta!(IESopt, :DocTestSetup, :(using IESopt); recursive=true)

makedocs(;
    modules=[IESopt],
    authors="Stefan Strömer <stefan.stroemer@ait.ac.at> and contributors",
    sitename="IESopt.jl",
    format=Documenter.HTML(;
        canonical="https://ait-energy.github.io/IESopt.jl",
        edit_link="dev",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ait-energy/IESopt.jl",
    devbranch="dev",
)
