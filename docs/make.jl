using Flatland
using Documenter: Documenter, DocMeta, makedocs, deploydocs

DocMeta.setdocmeta!(Flatland, :DocTestSetup, :(using Flatland); recursive=true)

cp(
    joinpath(dirname(@__DIR__), "README.md"),
    joinpath(@__DIR__, "src", "index.md");
    force=true,
)

makedocs(;
    modules=[Flatland],
    authors="Guillaume Dalle, Chun-Tso Tsai",
    sitename="Flatland.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://gdalle.github.io/Flatland.jl",
    ),
    pages=["Home" => "index.md", "API reference" => "api.md"],
)

deploydocs(; repo="github.com/gdalle/Flatland.jl", devbranch="main", push_preview=true)
