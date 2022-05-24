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
K = 10  # nb of instances

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

mapfs = Vector{FlatlandMAPF}(undef, 2K);
@showprogress "Generating instances" for k in 1:2K
    pyenv.reset()
    mapfs[k] = flatland_mapf(pyenv)
end

## Lower bound

solutions_indep = Vector{Solution}(undef, 2K);
@threads for k in 1:2K
    mapf = mapfs[k]
    solution = independent_dijkstra(mapf)
    solutions_indep[k] = solution
end

## Feasible solutions

solutions_coop = Vector{Solution}(undef, 2K);
@threads for k in 1:2K
    mapf = mapfs[k]
    solution = cooperative_astar(mapf, 1:A)
    solutions_coop[k] = solution
end

solutions_lns2 = Vector{Solution}(undef, 2K);
prog = Progress(2K; desc="Feasibility search");
@threads for k in 1:2K
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

## Eval on train dataset

mean(flowtime.(solutions_coop[1:K], mapfs[1:K]))
mean(flowtime.(solutions_lns2[1:K], mapfs[1:K]))
mean(flowtime.(solutions_indep[1:K], mapfs[1:K]))

solutions_opt = solutions_lns2;

## Build features

X = Vector{Matrix{Float64}}(undef, 2K * A);
Y = Vector{SparseVector{Int}}(undef, 2K * A);
prog = Progress(2K; desc="Instance embedding");
@threads for k in 1:2K
    next!(prog)
    mapf = mapfs[k]
    solution_indep = solutions_indep[k]
    solution_opt = solutions_opt[k]
    for a in 1:A
        p = (k - 1) * A + a
        X[p] = mapf_embedding(a, solution_indep, mapf)
        Y[p] = path_to_vec_sparse(solution_opt[a], mapf)
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

make_negative(z) = .-softplus.(z) .- 1e-1;
dropfirstdim(z) = dropdims(z; dims=1);

perturbed = PerturbedLogNormal(maximizer; ε=1, M=5)
fenchel_young_loss = FenchelYoungLoss(perturbed)

initial_encoder = Chain(
    Dense(F, 1, identity),
    dropfirstdim,
    make_negative,
)
encoder = deepcopy(initial_encoder)

par = Flux.params(encoder);
opt = ADAM(1e-4)

diversification = (
    sum(!iszero, perturbed(-mapfs[1].edge_weights_vec; a=1, mapf=mapfs[1])) /
    sum(!iszero, maximizer(-mapfs[1].edge_weights_vec; a=1, mapf=mapfs[1]))
)

## Training

nb_epochs = 30
losses, distances = Float64[], Float64[]
for epoch in 1:nb_epochs
    l, d = 0.0, 0.0
    prog = Progress(K * A; desc="Epoch $epoch")
    grads = Vector{Flux.Zygote.Grads}(undef, K * A)
    @threads for k in 1:K
        @threads for a in 1:A
            next!(prog)
            mapf = mapfs[k]
            p = (k - 1) * A + a
            x, y = X[p], Y[p]
            ŷ = maximizer(encoder(x); a=a, mapf=mapf)
            d += sum(abs, ŷ - y)
            grads[p] = gradient(par) do
                l += fenchel_young_loss(encoder(x), y; a=a, mapf=mapf)
            end
        end
    end
    for gs in grads
        Flux.update!(opt, par, gs)
    end
    @info "After epoch $epoch: loss $l - distance $d"
    push!(losses, l)
    push!(distances, d)
    epoch > 1 && losses[end] ≈ losses[end - 1] && break
end;

println(lineplot(log.(losses); xlabel="Epoch", ylabel="FYL"))
println(lineplot(log.(distances); xlabel="Epoch", ylabel="Hamming dist"))

## Eval

solutions_pred_init = Vector{Solution}(undef, 2K);
solutions_pred_final = Vector{Solution}(undef, 2K);
prog = Progress(2K; desc="Prediction");
@threads for k in 1:2K
    next!(prog)
    mapf = mapfs[k]
    edge_weights_mat_init = reduce(hcat, -initial_encoder(X[(k - 1) * A + a]) for a in 1:A)
    edge_weights_mat_final = reduce(hcat, -encoder(X[(k - 1) * A + a]) for a in 1:A)
    solutions_pred_init[k] = cooperative_astar(mapf, 1:A, edge_weights_mat_init)
    solutions_pred_final[k] = cooperative_astar(mapf, 1:A, edge_weights_mat_final)
end

## Eval on training set

mean(flowtime.(solutions_pred_init[1:K], mapfs[1:K]))
mean(flowtime.(solutions_coop[1:K], mapfs[1:K]))
mean(flowtime.(solutions_pred_final[1:K], mapfs[1:K]))
mean(flowtime.(solutions_opt[1:K], mapfs[1:K]))
mean(flowtime.(solutions_indep[1:K], mapfs[1:K]))


## Eval on test set

mean(flowtime.(solutions_pred_init[K+1:2K], mapfs[K+1:2K]))
mean(flowtime.(solutions_coop[K+1:2K], mapfs[K+1:2K]))
mean(flowtime.(solutions_pred_final[K+1:2K], mapfs[K+1:2K]))
mean(flowtime.(solutions_opt[K+1:2K], mapfs[K+1:2K]))
mean(flowtime.(solutions_indep[K+1:2K], mapfs[K+1:2K]))
