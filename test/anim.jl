using Flatland
using GLMakie
using Graphs
using MultiAgentPathFinding

rail_generator = rail_generators.sparse_rail_generator(; max_num_cities=5)
line_generator = line_generators.sparse_line_generator()

pyenv = rail_env.RailEnv(;
    width=40,
    height=25,
    number_of_agents=30,
    rail_generator=rail_generator,
    line_generator=line_generator,
    random_seed=11,
)

pyenv.reset();
mapf = flatland_mapf(pyenv);

solution_coop = cooperative_astar(mapf, 1:nb_agents(mapf));
is_feasible(solution_coop, mapf)
flowtime(solution_coop, mapf)

framerate = 6

fig, (A, XY, M, T) = plot_flatland_graph(mapf; title="Cooperative A*");
fig
tmax = MultiAgentPathFinding.makespan(solution_coop)
for t in 1:tmax
    A[], XY[], M[] = flatland_agent_coords(mapf, solution_coop, t)
    T[] = "Time: $t"
    sleep(1 / framerate)
end

# record(fig, "coop_astar.gif", 1:tmax; framerate=framerate) do t
#     A[], XY[], M[] = flatland_agent_coords(mapf, solution_coop, t)
#     T[] = "Time: $t"
# end
