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
    height=25,
    number_of_agents=30,
    rail_generator=rail_generator,
    line_generator=line_generator,
    random_seed=11
)

pyenv.reset();
mapf = flatland_mapf(pyenv);

solution_coop_bad = cooperative_astar(mapf, reverse(1:nb_agents(mapf)));
solution_coop_good = cooperative_astar(mapf, 1:nb_agents(mapf));
is_feasible(solution_coop_bad, mapf)
is_feasible(solution_coop_good, mapf)
flowtime(solution_coop_bad, mapf)
flowtime(solution_coop_good, mapf)

framerate = 6

fig, (A, XY, M, T) = plot_flatland_graph(mapf; title = "Prioritized planning with a bad order");
fig
tmax_bad = max_time(solution_coop_bad)
record(fig, "coop_astar_bad.gif", 1:tmax_bad; framerate=framerate) do t
    A[], XY[], M[] = flatland_agent_coords(mapf, solution_coop_bad, t)
    T[] = "Time: $t"
end

fig, (A, XY, M, T) = plot_flatland_graph(mapf; title = "Prioritized planning with a better order");
fig
tmax_good = max_time(solution_coop_good)
record(fig, "coop_astar_good.gif", 1:tmax_good; framerate=framerate) do t
    A[], XY[], M[] = flatland_agent_coords(mapf, solution_coop_good, t)
    T[] = "Time: $t"
end

# @showprogress for t in 1:tmax
#     A[], XY[], M[] = flatland_agent_coords(mapf, solution, t)
#     sleep(1 / framerate)
# end
