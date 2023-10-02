using Aqua: Aqua
using Documenter: Documenter
using Flatland
using JET: JET
using JuliaFormatter: JuliaFormatter
using Test

@testset "Flatland.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Flatland)
    end
    @testset "Formatting (JuliaFormatter.jl)" begin
        @test JuliaFormatter.format(Flatland; verbose=false, overwrite=false)
    end
    @testset "Static checking (JET.jl)" begin
        JET.test_package(Flatland; target_defined_modules=true)
    end
    @testset "Doctests (Documenter.jl)" begin
        Documenter.doctest(Flatland)
    end
end
