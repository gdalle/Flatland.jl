## Imports

using Base.Threads
nthreads()

using BenchmarkTools
using Flatland
using Graphs
using InferOpt
using Lux, Lux.NNlib, Lux.Optimisers
using MultiAgentPathFinding
using ProgressMeter
using PythonCall
using Random: Random, GLOBAL_RNG
using SparseArrays
using Statistics
using UnicodePlots
using Zygote

Random.seed!(63)

## Settings

W = 30  # width
H = 30  # height
C = 3  # cities
A = 50  # agents
K = 1  # nb of instances

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
@showprogress "Generating instances" for k in 1:K
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
    solution = cooperative_astar(mapf, sortperm(1:A; by=a -> mapf.starting_times[a]))
    solutions_coop[k] = solution
end

solutions_lns2 = Vector{Solution}(undef, K);
prog = Progress(K; desc="Feasibility search");
@threads for k in 1:K
    next!(prog)
    mapf = mapfs[k]
    solution, steps = feasibility_search(
        mapf;
        conflict_price=1.0,
        conflict_price_increase=1e-2,
        neighborhood_size=5,
        show_progress=false,
    )
    solutions_lns2[k] = solution
end

## Eval on train dataset

mean(flowtime.(solutions_coop, mapfs))
mean(flowtime.(solutions_lns2, mapfs))
mean(flowtime.(solutions_indep, mapfs))

## Build features

X = Vector{Matrix{Float64}}(undef, K * A);
Y = Vector{SparseVector{Int}}(undef, K * A);
prog = Progress(K; desc="Instance embedding");
@threads for k in 1:K
    next!(prog)
    mapf = mapfs[k]
    solution_for_features = solutions_indep[k]
    solution_to_imitate = solutions_lns2[k]
    for a in 1:A
        i = (k - 1) * A + a
        # X[i] = mapf_embedding(a, solution_for_features, mapf)
        X[i] = randn(100, ne(mapf.g))
        Y[i] = path_to_vec_sparse(solution_to_imitate[a], mapf)
    end
end

F = size(X[1], 1)

## Define pipeline

function maximizer(θ; a, mapf)
    edge_weights_vec = -θ
    timed_path = agent_dijkstra(a, mapf, edge_weights_vec)
    ŷ = path_to_vec_sparse(timed_path, mapf)
    return ŷ
end

## Initialization

make_negative(z) = .-softplus.(z) .- 1e-2;
dropfirstdim(z) = dropdims(z; dims=1);

encoder = Chain(
    Dense(F, F ÷ 4, relu),
    Dense(F ÷ 4, F ÷ 16, relu),
    Dense(F ÷ 16, 1 , relu),
    dropfirstdim,
    make_negative,
)

perturbed = PerturbedLogNormal(maximizer; ε=0.3, M=3);
fenchel_young_loss = FenchelYoungLoss(perturbed);

diversification = (
    sum(!iszero, perturbed(-mapfs[1].edge_weights_vec; a=1, mapf=mapfs[1])) /
    sum(!iszero, maximizer(-mapfs[1].edge_weights_vec; a=1, mapf=mapfs[1]))
)

ps, st = Lux.setup(GLOBAL_RNG, encoder);
st_opt = Optimisers.setup(ADAM(1e-3), ps);

## Training

nb_epochs = 100;
losses, distances = Float64[], Float64[];
prog = Progress(nb_epochs; desc="Training", enabled=true);
for epoch in 1:nb_epochs
    l, d = 0.0, 0.0
    for k in 1:K, a in 1:A
        mapf = mapfs[k]
        i = (k - 1) * A + a
        x, y = X[i], Y[i]
        θ, _ = Lux.apply(encoder, x, ps, st)
        ŷ = maximizer(θ; a=a, mapf=mapf)
        d += sum(abs, ŷ - y)
        gs = gradient(ps) do p
            θ, _ = Lux.apply(encoder, x, p, st)
            l += fenchel_young_loss(θ, y; a=a, mapf=mapf)
        end
        st_opt, ps = Optimisers.update(st_opt, ps, first(gs))
    end
    next!(prog; showvalues=[(:loss, l), (:distance, d)])
    push!(losses, l)
    push!(distances, d)
    epoch > 1 && (losses[end] ≈ losses[end - 1] || iszero(distances[end])) && break
end;

# println(lineplot(log.(losses); xlabel="Epoch", ylabel="FYL"))
println(lineplot(distances; xlabel="Epoch", ylabel="Hamming dist"))

## Eval

solutions_pred = Vector{Solution}(undef, K);
prog = Progress(K; desc="Prediction");
@threads for k in 1:K
    next!(prog)
    mapf = mapfs[k]
    edge_weights_vecs = [-Lux.apply(encoder, X[(k - 1) * A + a], ps, st)[1] for a in 1:A]
    edge_weights_mat = reduce(hcat, edge_weights_vecs)
    agents = sortperm(1:A; by=a -> mapf.starting_times[a])
    solutions_pred[k] = cooperative_astar(mapf, agents, edge_weights_mat)
end

## Eval on training set

mean(flowtime.(solutions_coop, mapfs))
mean(flowtime.(solutions_pred, mapfs))
mean(flowtime.(solutions_lns2, mapfs))
mean(flowtime.(solutions_indep, mapfs))
