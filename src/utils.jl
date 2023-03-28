function reverse_direction(direction::Direction)
    if direction == north
        return south
    elseif direction == south
        return north
    elseif direction == west
        return east
    elseif direction == east
        return west
    end
end

## Grid utilities

function neighbor_cell((i, j)::NTuple{2,<:Integer}, out_direction::Direction)
    if out_direction == north
        return (i - 1, j)
    elseif out_direction == east
        return (i, j + 1)
    elseif out_direction == south
        return (i + 1, j)
    elseif out_direction == west
        return (i, j - 1)
    end
end

function transition_exists(
    transition_map::String, in_direction::Direction, out_direction::Direction
)
    return transition_map[4(Int(in_direction) - 1) + Int(out_direction)] == '1'
end

function direction_exists(transition_map::String, in_direction::Direction)
    return any(
        transition_exists(transition_map, in_direction, out_direction) for
        out_direction in (north, east, south, west)
    )
end

## Vertex utilities

function vertices_on_cell(g, label::VertexLabel)
    (; position, direction) = label
    return (
        code_for(g, (position, direction, real)) for
        direction in (north, east, south, west) if haskey(g, (position, direction, real))
    )
end

function mirror_vertex(g, label::VertexLabel)
    (; position, direction, role) = label
    if role == real
        neighbor_position = neighbor_cell(position, reverse_direction(direction))
        mirror_label = VertexLabel(neighbor_position, reverse_direction(direction), real)
        return code_for(g, mirror_label)
    end
end

vertices_on_cell(g, v::Integer) = vertices_on_cell(g, label_for(g, v))
mirror_vertex(g, v::Integer) = mirror_vertex(g, label_for(g, v))
is_real_vertex(g, v::Integer) = label_for(g, v).role == real
