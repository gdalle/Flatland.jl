using Flatland
using MultiAgentPathFinding
using Test

## Test

rail_generator = rail_generators.sparse_rail_generator(; max_num_cities=10)
line_generator = line_generators.sparse_line_generator()

pyenv = rail_env.RailEnv(;
    width=50,
    height=50,
    number_of_agents=100,
    rail_generator=rail_generator,
    line_generator=line_generator,
    random_seed=63,
)

pyenv.reset();
mapf = flatland_mapf(pyenv);

solution_indep = independent_dijkstra(mapf);
is_feasible(solution_indep, mapf)
flowtime(solution_indep, mapf)

solution_coop = cooperative_astar(mapf, 1:nb_agents(mapf));
is_feasible(solution_coop, mapf)
flowtime(solution_coop, mapf)

@test !is_feasible(solution_indep, mapf)
@test is_feasible(solution_coop, mapf)
@test flowtime(solution_indep, mapf) <= flowtime(solution_coop, mapf)
