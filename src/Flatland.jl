module Flatland

using Graphs
using MetaDataGraphs
using MultiAgentPathFinding
using PythonCall
using Requires

include("constants.jl")
include("agent.jl")
include("graph.jl")
include("utils.jl")
include("mapf.jl")

export flatland_mapf

function __init__()
    @require GLMakie="e9467ef8-e4e7-5192-8a1a-b1aee30e663a" begin
        using .GLMakie
        include("plot.jl")
        export plot_flatland_graph, flatland_agent_coords
    end
end

end
