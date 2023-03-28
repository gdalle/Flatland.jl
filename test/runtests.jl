## Imports

using Aqua
using Documenter
using Flatland
using GLMakie
using JuliaFormatter
using Random
using Test

DocMeta.setdocmeta!(Flatland, :DocTestSetup, :(using Flatland); recursive=true)

## Test sets

@testset verbose = true "Flatland.jl" begin
    @testset verbose = false "Code quality" begin
        Aqua.test_all(Flatland; ambiguities=false)
    end
    @testset verbose = true "Code formatting" begin
        @test format(Flatland; overwrite=false)
    end
    doctest(Flatland)
    @testset verbose = true "Multi-Agent Path Finding" begin
        include("mapf.jl")
    end
    @testset verbose = true "Animation" begin
        include("anim.jl")
    end
end
