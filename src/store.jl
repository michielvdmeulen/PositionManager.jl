abstract type AbstractPositionStore end

function save!(store::AbstractPositionStore, position::Position)::Nothing
    throw(MethodError(save!, (store, position)))
end

function load_open(store::AbstractPositionStore)::Vector{Position}
    throw(MethodError(load_open, (store,)))
end

function load_ungrouped(store::AbstractPositionStore)::Vector{PositionLegRecord}
    throw(MethodError(load_ungrouped, (store,)))
end

function save_ungrouped!(
        store::AbstractPositionStore,
        legs::Vector{PositionLegRecord}
)::Nothing
    throw(MethodError(save_ungrouped!, (store, legs)))
end

mutable struct PositionStore <: AbstractPositionStore
    positions::Dict{UUID, Position}
    ungrouped::Vector{PositionLegRecord}
    order_id_index::Dict{Int, UUID}
end

PositionStore() = PositionStore(Dict{UUID, Position}(), PositionLegRecord[], Dict{Int, UUID}())

function save!(store::PositionStore, position::Position)::Nothing
    store.positions[position.id] = position
    return nothing
end

function load_open(store::PositionStore)::Vector{Position}
    open_positions = Position[]
    for position in values(store.positions)
        position.status == Closed && continue
        push!(open_positions, position)
    end
    return sort!(open_positions; by = pos -> pos.opened_at)
end

function load_ungrouped(store::PositionStore)::Vector{PositionLegRecord}
    return copy(store.ungrouped)
end

function save_ungrouped!(store::PositionStore, legs::Vector{PositionLegRecord})::Nothing
    store.ungrouped = copy(legs)
    return nothing
end
