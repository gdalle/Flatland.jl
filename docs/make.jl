using Flatland
using Documenter

DocMeta.setdocmeta!(Flatland, :DocTestSetup, :(using Flatland); recursive=true)

makedocs(;
    modules=[Flatland],
    authors="Guillaume Dalle, Chun-Tso Tsai",
    repo="https://github.com/gdalle/Flatland.jl/blob/{commit}{path}#{line}",
    sitename="Flatland.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://gdalle.github.io/Flatland.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/gdalle/Flatland.jl",
    devbranch="main",
)
