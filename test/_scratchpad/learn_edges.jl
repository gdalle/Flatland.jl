## Imports

using Base.Threads
nthreads()

using BenchmarkTools
using Flatland
using Flux
using Graphs
using InferOpt
using MultiAgentPathFinding
using ProgressMeter
using PythonCall
using Random
using SparseArrays
using Statistics
using UnicodePlots

Random.seed!(63)

## Settings

W = 40  # width
H = 40  # height
C = 5  # cities
A = 100  # agents
K = 50  # nb of instances

## Data generation

rail_generators = pyimport("flatland.envs.rail_generators");
line_generators = pyimport("flatland.envs.line_generators");
rail_env = pyimport("flatland.envs.rail_env");

rail_generator = rail_generators.sparse_rail_generator(; max_num_cities=C);
line_generator = line_generators.sparse_line_generator();

pyenv = rail_env.RailEnv(;
    width=W,
    height=H,
    number_of_agents=A,
    rail_generator=rail_generator,
    line_generator=line_generator,
    random_seed=63,
)

mapfs = Vector{FlatlandMAPF}(undef, K);
@showprogress "Generating instances: " for k in 1:K
    pyenv.reset()
    mapfs[k] = flatland_mapf(pyenv)
end

## Lower bound

solutions_indep = Vector{Solution}(undef, K);
@threads for k in 1:K
    mapf = mapfs[k]
    solution = independent_dijkstra(mapf)
    solutions_indep[k] = solution
end

## Feasible solutions

solutions_coop = Vector{Solution}(undef, K);
@threads for k in 1:K
    mapf = mapfs[k]
    solution = cooperative_astar(mapf, 1:A)
    solutions_coop[k] = solution
end

solutions_lns2 = Vector{Solution}(undef, K);
prog = Progress(K; desc="Feasibility search: ");
@threads for k in 1:K
    next!(prog)
    mapf = mapfs[k]
    solution = feasibility_search(
        mapf;
        conflict_price=1.,
        conflict_price_increase=1e-2,
        neighborhood_size=5,
        show_progress=false,
    )
    solutions_lns2[k] = solution
end

## Apply local search

# solutions_coop_lns1 = Vector{Solution}(undef, K);
# @threads for k in 1:K
#     @info "Instance $k solved by thread $(threadid()) (coop + LNS1)"
#     mapf = mapfs[k]
#     solution = deepcopy(solutions_coop[k])
#     large_neighborhood_search!(
#         solution, mapf; steps=A, neighborhood_size=A ÷ 10, progress=false
#     )
#     solutions_coop_lns1[k] = solution
# end

# solutions_lns2_lns1 = Vector{Solution}(undef, K);
# @threads for k in 1:K
#     @info "Instance $k solved by thread $(threadid()) (coop + LNS2)"
#     mapf = mapfs[k]
#     solution = deepcopy(solutions_lns2[k])
#     large_neighborhood_search!(
#         solution, mapf; steps=A, neighborhood_size=A ÷ 10, progress=false
#     )
#     solutions_lns2_lns1[k] = solution
# end

## Eval dataset

mean(flowtime.(solutions_indep, mapfs))
mean(flowtime.(solutions_coop, mapfs))
mean(flowtime.(solutions_lns2, mapfs))
# mean(flowtime.(solutions_coop_lns1, mapfs))
# mean(flowtime.(solutions_lns2_lns1, mapfs))

solutions_opt = solutions_lns2;

## Build features

imitate = "opt"

X = Vector{Array{Float64, 3}}(undef, K);
Y = Vector{Matrix{Int}}(undef, K);

@profview for _ = 1:100; solution_to_mat(solutions_indep[1], mapfs[1]); end

prog = Progress(K; desc="Instance embedding: ");
@threads for k in 1:K
    next!(prog)
    mapf, solution = mapfs[k], solutions_opt[k]
    X[k] = mapf_embedding(mapf)
    Y[k] = solution_to_mat(solution, mapf)
end

F = size(X[1], 1)

## Define pipeline

function maximizer(θ; mapf)
    edge_weights_mat = -θ
    solution = independent_dijkstra(mapf, edge_weights_mat)
    ŷ = solution_to_mat(solution, mapf)
    return ŷ
end

## Initialization

make_positive(z) = softplus.(z);
switch_sign(z) = -z;
dropfirstdim(z) = dropdims(z; dims=1);

perturbed = PerturbedLogNormal(maximizer; ε=1, M=5)
fenchel_young_loss = FenchelYoungLoss(perturbed)

initial_encoder = Chain(
    Dense(F, F, relu), Dense(F, 1), dropfirstdim, make_positive, switch_sign
)
encoder = deepcopy(initial_encoder)

par = Flux.params(encoder);
opt = ADAM()

diversification = (
    sum(!iszero, perturbed(encoder(X[1]); mapf=mapfs[1])) /
    sum(!iszero, maximizer(encoder(X[1]); mapf=mapfs[1]))
)

## Training

nb_epochs = 1
losses, distances = Float64[], Float64[]
@profview for epoch in 1:nb_epochs
    l = 0.0
    d = 0.0
    @showprogress "Epoch $epoch" for k in 1:K
        mapf, x, y = mapfs[k], X[k], Y[k]
        ŷ = maximizer(encoder(x); mapf=mapf)
        d += sum(abs, ŷ - y)
        gs = gradient(par) do
            l += fenchel_young_loss(encoder(x), y; mapf=mapf)
        end
        Flux.update!(opt, par, gs)
    end
    @info "After epoch $epoch: loss $l - distance $d"
    push!(losses, l)
    push!(distances, d)
    epoch > 1 && losses[end] ≈ losses[end - 1] && break
end;

lineplot(losses, xlabel="Epoch", ylabel="FYL") |> println
lineplot(distances, xlabel="Epoch", ylabel="Hamming dist") |> println

## Eval

solutions_pred_init = Vector{Solution}(undef, K);
solutions_pred_final = Vector{Solution}(undef, K);
@threads for k in 1:K  # Error
    @info "Instance $k solved by thread $(threadid())"
    mapf = mapfs[k]
    edge_weights_mat_init = reduce(hcat, -initial_encoder(X[(k - 1) * A + a]) for a in 1:A)
    edge_weights_mat_final = reduce(hcat, -encoder(X[(k - 1) * A + a]) for a in 1:A)
    solutions_pred_init[k] = cooperative_astar(mapf, 1:A, edge_weights_mat_init)
    solutions_pred_final[k] = cooperative_astar(mapf, 1:A, edge_weights_mat_final)
end

mean(flowtime.(solutions_indep, mapfs))
mean(flowtime.(solutions_coop, mapfs))
mean(flowtime.(solutions_opt, mapfs))

mean(flowtime.(solutions_pred_init, mapfs))
mean(flowtime.(solutions_pred_final, mapfs))
