struct VertexLabel
    position::Tuple{Int,Int}
    direction::Direction
    role::Role
end

function flatland_graph(pyenv::Py, agents::Vector{Agent})
    # Find stations
    initial_positions = unique(agent.initial_position for agent in agents)
    target_positions = unique(agent.target_position for agent in agents)

    # Retrieve grid
    width = pyconvert(Int, pyenv.width)
    height = pyconvert(Int, pyenv.height)
    grid = pyconvert(Matrix{UInt16}, pyenv.rail.grid)

    # Initialize g
    g = MetaGraph(
        DiGraph();
        label_type=VertexLabel,
        vertex_data_type=Nothing,
        edge_data_type=Int,
        graph_data=grid,
    )

    # Create vertices from non empty grid cells
    for i in 1:height, j in 1:width
        cell = grid[i, j]
        position = (i, j)
        if cell > 0
            transition_map = bitstring(cell)
            # Real vertices
            for direction in (north, east, south, west)
                if direction_exists(transition_map, direction)
                    label = VertexLabel(position, direction, real)
                    add_vertex!(g, label, nothing)
                end
            end
            # Departure vertices
            if position in initial_positions
                for direction in (north, east, south, west)
                    if direction_exists(transition_map, direction)
                        label = VertexLabel(position, direction, departure)
                        add_vertex!(g, label, nothing)
                    end
                end
            end
            # Arrival vertices
            if position in target_positions
                label = VertexLabel(position, no_direction, arrival)
                add_vertex!(g, label, nothing)
            end
        end
    end

    # Create out edges for every vertex
    for v in vertices(g)
        label_s = label_for(g, v)
        (; position, direction, role) = label_s
        (i, j) = position
        if role == real  # from real vertices
            cell = grid[i, j]
            transition_map = bitstring(cell)
            # to themselves
            add_edge!(g, label_s, label_s, 1)
            # to other real vertices
            for out_direction in (north, east, south, west)
                if transition_exists(transition_map, direction, out_direction)
                    neighbor_position = neighbor_cell(position, out_direction)
                    label_d = VertexLabel(neighbor_position, out_direction, real)
                    add_edge!(g, label_s, label_d, 1)
                end
            end
            # to arrival vertices
            if position in target_positions
                label_d = VertexLabel(position, no_direction, arrival)
                add_edge!(g, label_s, label_d, 0)
            end
        elseif role == departure  # from departure vertices
            # to themselves
            add_edge!(g, label_s, label_s, 1)
            # to real vertices
            label_d = VertexLabel(position, direction, real)
            add_edge!(g, label_s, label_d, 0)
        elseif role == arrival  # from arrival vertices
            # to themselves
            add_edge!(g, label_s, label_s, 0)
        end
    end
    return g
end

get_grid(g) = g.graph_data
get_height(g) = size(get_grid(g), 1)
get_width(g) = size(get_grid(g), 2)
