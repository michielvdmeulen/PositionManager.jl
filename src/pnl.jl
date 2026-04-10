function _open_legs(position::Position)
    return filter(leg -> !iszero(leg.quantity), position.legs)
end

function _chain_mid(chain::OptionChains.ChainState, conid::Int)::Float64
    idx = get(chain.universe.by_ticker, string(conid), nothing)
    idx === nothing && return 0.0
    quote_state = chain.contracts[idx].quote_state
    quote_state === nothing && return 0.0
    return (quote_state.bid + quote_state.ask) / 2.0
end

function _vertical_bounds(legs::Vector{PositionLegRecord}, multiplier::Float64)
    length(legs) == 2 || return (nothing, nothing)
    q = abs(legs[1].quantity)
    q > 0 || return (nothing, nothing)
    strike_diff = abs(legs[1].strike - legs[2].strike)
    net_debit_per_unit = sum(leg.avg_fill_price * sign(leg.quantity) for leg in legs)
    if net_debit_per_unit >= 0
        max_loss = net_debit_per_unit * multiplier * q
        max_profit = max((strike_diff - net_debit_per_unit) * multiplier * q, 0.0)
    else
        credit = -net_debit_per_unit
        max_profit = credit * multiplier * q
        max_loss = max((strike_diff - credit) * multiplier * q, 0.0)
    end
    return (max_profit, max_loss)
end

function _butterfly_bounds(legs::Vector{PositionLegRecord}, multiplier::Float64)
    ordered = sort(collect(legs); by = leg -> leg.strike)
    wing_width = ordered[2].strike - ordered[1].strike
    n = abs(ordered[1].quantity)
    net_debit = sum(leg.avg_fill_price * leg.quantity for leg in ordered) * multiplier
    max_profit = wing_width * multiplier * n - net_debit
    return (max_profit, net_debit)
end

function _single_leg_bounds(leg::PositionLegRecord, multiplier::Float64)
    premium = abs(leg.quantity) * leg.avg_fill_price * multiplier
    if leg.quantity > 0
        return leg.right == :call ? (nothing, premium) : (nothing, premium)
    end
    return (premium, nothing)
end

function _max_bounds(
        strategy_label::Union{Nothing, String},
        legs::Vector{PositionLegRecord},
        multiplier::Float64
)
    strategy_label === nothing && return (nothing, nothing)
    if startswith(strategy_label, "put_butterfly_") || startswith(strategy_label, "call_butterfly_")
        return _butterfly_bounds(legs, multiplier)
    elseif strategy_label in ("call_vertical", "put_vertical")
        return _vertical_bounds(legs, multiplier)
    elseif strategy_label in ("long_call", "short_call", "long_put", "short_put")
        return _single_leg_bounds(legs[1], multiplier)
    end
    return (nothing, nothing)
end

function compute_pnl(
        position::Position,
        chain::OptionChains.ChainState,
        multiplier::Float64 = 100.0
)::PositionPnL
    unrealized = 0.0
    open_legs = _open_legs(position)
    for leg in open_legs
        current_mid = _chain_mid(chain, leg.conid)
        unrealized += (current_mid - leg.avg_fill_price) * leg.quantity * multiplier
    end
    realized = position.realized_pnl
    total = unrealized + realized
    strategy_label = detect_strategy(open_legs)
    max_profit, max_loss = _max_bounds(strategy_label, open_legs, multiplier)
    pct_of_max_profit = (max_profit === nothing || iszero(max_profit)) ? nothing :
                        unrealized / max_profit
    pct_of_max_loss = (max_loss === nothing || iszero(max_loss)) ? nothing : unrealized / max_loss
    return PositionPnL(
        unrealized,
        realized,
        total,
        max_profit,
        max_loss,
        pct_of_max_profit,
        pct_of_max_loss
    )
end

function breakevens(position::Position, multiplier::Float64 = 100.0)::Vector{Float64}
    legs = _open_legs(position)
    label = detect_strategy(legs)
    label === nothing && return Float64[]
    if startswith(label, "put_butterfly_") || startswith(label, "call_butterfly_")
        ordered = sort(collect(legs); by = leg -> leg.strike)
        n = abs(ordered[1].quantity)
        debit_per_unit = (sum(leg.avg_fill_price * leg.quantity for leg in ordered) * multiplier) /
                         (multiplier * n)
        return [ordered[1].strike + debit_per_unit, ordered[3].strike - debit_per_unit]
    elseif label == "call_vertical"
        ordered = sort(collect(legs); by = leg -> leg.strike)
        q = abs(ordered[1].quantity)
        debit_per_unit = sum(leg.avg_fill_price * sign(leg.quantity) for leg in ordered) / q
        return [ordered[1].strike + debit_per_unit]
    elseif label == "put_vertical"
        ordered = sort(collect(legs); by = leg -> leg.strike)
        q = abs(ordered[1].quantity)
        debit_per_unit = sum(leg.avg_fill_price * sign(leg.quantity) for leg in ordered) / q
        return [ordered[end].strike - debit_per_unit]
    elseif label == "long_call"
        leg = only(legs)
        return [leg.strike + leg.avg_fill_price]
    elseif label == "long_put"
        leg = only(legs)
        return [leg.strike - leg.avg_fill_price]
    end
    return Float64[]
end
