module Flatland

using GLMakie
using Graphs
using MetaGraphsNext
using MultiAgentPathFinding
using PythonCall

const rail_generators = PythonCall.pynew()
const line_generators = PythonCall.pynew()
const rail_env = PythonCall.pynew()

function __init__()
    PythonCall.pycopy!(rail_generators, pyimport("flatland.envs.rail_generators"))
    PythonCall.pycopy!(line_generators, pyimport("flatland.envs.line_generators"))
    return PythonCall.pycopy!(rail_env, pyimport("flatland.envs.rail_env"))
end

include("constants.jl")
include("agent.jl")
include("graph.jl")
include("utils.jl")
include("mapf.jl")
include("anim.jl")

export rail_generators, line_generators, rail_env
export flatland_mapf
export plot_flatland_graph, flatland_agent_coords

end
