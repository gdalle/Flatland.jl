function flatland_vertex_conflicts(g, v::Integer)
    if is_real_vertex(g, v)
        mv = mirror_vertex(g, v)
        cv = vertices_on_cell(g, v)
        return Int[mv, cv...]
    else
        return Int[]
    end
end

function flatland_mapf(pyenv::Py)
    agents = [Agent(pyagent) for pyagent in pyenv.agents]
    g = flatland_graph(pyenv, agents)
    departures = [code_for(g, initial_label(agent)) for agent in agents]
    arrivals = [code_for(g, target_label(agent)) for agent in agents]
    departure_times = [agent.earliest_departure for agent in agents]
    vertex_conflicts = [flatland_vertex_conflicts(g, v) for v in vertices(g)]
    mapf = MAPF(
        g;
        departures=departures,
        arrivals=arrivals,
        departure_times=departure_times,
        vertex_conflicts=vertex_conflicts,
    )
    return mapf
end
