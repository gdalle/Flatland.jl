using Flatland
using Documenter

DocMeta.setdocmeta!(Flatland, :DocTestSetup, :(using Flatland); recursive=true)

makedocs(;
    modules=[Flatland],
    authors="Guillaume Dalle <22795598+gdalle@users.noreply.github.com> and contributors",
    repo="https://github.com/gdalle/Flatland.jl/blob/{commit}{path}#{line}",
    sitename="Flatland.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://gdalle.github.io/Flatland.jl",
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
