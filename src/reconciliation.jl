function _signed_quantity(leg::MarketState.PositionLeg)::Int
    return leg.action == :sell ? -leg.quantity : leg.quantity
end

function _to_leg_record(leg::MarketState.PositionLeg, timestamp::DateTime)::PositionLegRecord
    return PositionLegRecord(
        leg.conid,
        leg.symbol,
        leg.right,
        leg.strike,
        leg.expiry,
        _signed_quantity(leg),
        leg.avg_fill_price,
        timestamp
    )
end

function _append_leg(position::Position, leg::PositionLegRecord)::Position
    legs = copy(position.legs)
    push!(legs, leg)
    strategy_label = detect_strategy(legs)
    return Position(
        position.id,
        legs,
        position.campaign,
        strategy_label,
        position.status,
        position.opened_at,
        position.closed_at,
        position.notes,
        position.realized_pnl
    )
end

function _new_position(
        legs::Vector{PositionLegRecord},
        campaign::String,
        timestamp::DateTime
)::Position
    label = detect_strategy(legs)
    return Position(;
        legs = legs,
        campaign = campaign,
        strategy_label = label,
        status = Open,
        opened_at = timestamp,
        realized_pnl = 0.0
    )
end

function _matching_position_for_feed(
        store::PositionStore,
        leg::PositionLegRecord
)::Union{Nothing, Position}
    for position in load_open(store)
        for existing in position.legs
            existing.conid == leg.conid || continue
            sign(existing.quantity) == sign(leg.quantity) || continue
            if abs(existing.quantity) == abs(leg.quantity)
                return position
            end
            @warn "position feed quantity mismatch" conid=leg.conid expected=existing.quantity observed=leg.quantity delta=(leg.quantity - existing.quantity)
            return nothing
        end
    end
    return nothing
end

function apply_position_event!(
        store::PositionStore,
        event::MarketState.PositionEvent
)::Nothing
    if event.source == MarketState.ExecutionSource
        order_id = event.order_id
        campaign = something(event.campaign, "default")
        for leg in event.legs
            record = _to_leg_record(leg, event.timestamp)
            if order_id !== nothing && haskey(store.order_id_index, order_id)
                position_id = store.order_id_index[order_id]
                current = store.positions[position_id]
                updated = _append_leg(current, record)
                save!(store, updated)
            else
                created = _new_position([record], campaign, event.timestamp)
                save!(store, created)
                order_id === nothing || (store.order_id_index[order_id] = created.id)
            end
        end
    elseif event.source == MarketState.PositionFeedSource
        for leg in event.legs
            record = _to_leg_record(leg, event.timestamp)
            matching_position = _matching_position_for_feed(store, record)
            if matching_position === nothing
                push!(store.ungrouped, record)
            end
        end
    elseif event.source == MarketState.ManualSource
        campaign = something(event.campaign, "default")
        records = PositionLegRecord[_to_leg_record(leg, event.timestamp) for leg in event.legs]
        created = _new_position(records, campaign, event.timestamp)
        save!(store, created)
    end
    return nothing
end

function apply_partial_close!(
        store::PositionStore,
        position_id::UUID,
        closing_legs::Vector{MarketState.PositionLeg},
        multiplier::Float64 = DEFAULT_OPTION_MULTIPLIER;
        now_dt::DateTime = Dates.now()
)::Nothing
    haskey(store.positions, position_id) || throw(KeyError(position_id))
    current = store.positions[position_id]
    by_conid = Dict{Int, PositionLegRecord}(leg.conid => leg for leg in current.legs)
    realized_delta = 0.0

    for closing_leg in closing_legs
        haskey(by_conid, closing_leg.conid) || continue
        record = by_conid[closing_leg.conid]
        direction = sign(record.quantity)
        closing_qty = closing_leg.quantity
        realized_delta += (closing_leg.avg_fill_price - record.avg_fill_price) *
                          closing_qty * multiplier * direction
        new_quantity = record.quantity - closing_qty * direction
        by_conid[closing_leg.conid] = PositionLegRecord(
            record.conid,
            record.symbol,
            record.right,
            record.strike,
            record.expiry,
            new_quantity,
            record.avg_fill_price,
            record.open_timestamp
        )
    end

    updated_legs = collect(values(by_conid))
    open_legs = filter(leg -> !iszero(leg.quantity), updated_legs)
    status = isempty(open_legs) ? Closed : PartialClose
    closed_at = status == Closed ? now_dt : current.closed_at
    label = detect_strategy(open_legs)
    updated = Position(
        current.id,
        updated_legs,
        current.campaign,
        label,
        status,
        current.opened_at,
        closed_at,
        current.notes,
        current.realized_pnl + realized_delta
    )
    save!(store, updated)
    return nothing
end

function group_ungrouped!(
        store::PositionStore,
        conids::Vector{Int},
        campaign::String = "default";
        now_dt::DateTime = Dates.now()
)::Position
    chosen = PositionLegRecord[]
    remaining = PositionLegRecord[]
    conid_set = Set(conids)
    for leg in store.ungrouped
        if leg.conid in conid_set
            push!(chosen, leg)
        else
            push!(remaining, leg)
        end
    end
    isempty(chosen) && throw(ArgumentError("no matching ungrouped legs for requested conids"))
    store.ungrouped = remaining
    created = _new_position(chosen, campaign, now_dt)
    save!(store, created)
    return created
end
