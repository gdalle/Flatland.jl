using Flatland
using GLMakie
using Graphs
using MultiAgentPathFinding
using PythonCall
using ProgressMeter

rail_generators = pyimport("flatland.envs.rail_generators")
line_generators = pyimport("flatland.envs.line_generators")
rail_env = pyimport("flatland.envs.rail_env")

rail_generator = rail_generators.sparse_rail_generator(; max_num_cities=5)
line_generator = line_generators.sparse_line_generator()

pyenv = rail_env.RailEnv(;
    width=40,
    height=40,
    number_of_agents=50,
    rail_generator=rail_generator,
    line_generator=line_generator,
    random_seed=11,
)

pyenv.reset();
mapf = flatland_mapf(pyenv);

solution_coop = cooperative_astar(mapf, 1:nb_agents(mapf));
is_feasible(solution_coop, mapf)
flowtime(solution_coop, mapf)

fig, (A, XY, M) = plot_flatland_graph(mapf);
fig
solution = copy(solution_coop);
framerate = 3
tmax = max_time(solution)
@showprogress for t in 1:tmax
    A[], XY[], M[] = flatland_agent_coords(mapf, solution, t)
    sleep(1 / framerate)
end
