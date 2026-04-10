function _open_legs(position::Position)
    return filter(leg -> !iszero(leg.quantity), position.legs)
end

const DEFAULT_OPTION_MULTIPLIER = 100.0

function _chain_mid(chain::OptionChains.ChainState, conid::Int)::Float64
    idx = get(chain.universe.by_ticker, string(conid), nothing)
    idx === nothing && return 0.0
    quote_state = chain.contracts[idx].quote_state
    quote_state === nothing && return 0.0
    return (quote_state.bid + quote_state.ask) / 2.0
end

function _inferred_multiplier(
        position::Position,
        chain::OptionChains.ChainState
)::Float64
    for leg in position.legs
        idx = get(chain.universe.by_ticker, string(leg.conid), nothing)
        idx === nothing && continue
        return chain.universe.nodes[idx].multiplier
    end
    return DEFAULT_OPTION_MULTIPLIER
end

_is_call(right::Symbol) = right == :call || right == :CALL
_is_put(right::Symbol) = right == :put || right == :PUT

function _supports_payoff_math(legs::Vector{PositionLegRecord})::Bool
    return all(leg ->
        leg.right !== nothing && leg.strike !== nothing &&
        (_is_call(leg.right) || _is_put(leg.right)),
        legs
    )
end

function _intrinsic(leg::PositionLegRecord, underlying_price::Float64)::Float64
    strike = leg.strike::Float64
    right = leg.right::Symbol
    if _is_call(right)
        return max(underlying_price - strike, 0.0)
    end
    return max(strike - underlying_price, 0.0)
end

function _position_value_at_expiry(
        legs::Vector{PositionLegRecord},
        underlying_price::Float64,
        multiplier::Float64
)::Float64
    value = 0.0
    for leg in legs
        value += (leg.quantity * (_intrinsic(leg, underlying_price) - leg.avg_fill_price)) *
                 multiplier
    end
    return value
end

function _max_bounds(legs::Vector{PositionLegRecord}, multiplier::Float64)
    isempty(legs) && return (nothing, nothing)
    _supports_payoff_math(legs) || return (nothing, nothing)
    strikes = sort(unique(leg.strike::Float64 for leg in legs))
    candidates = unique(vcat(0.0, strikes))
    payouts = map(spot -> _position_value_at_expiry(legs, spot, multiplier), candidates)
    net_call_qty = sum(_is_call(leg.right::Symbol) ? leg.quantity : 0 for leg in legs)
    max_profit = net_call_qty > 0 ? nothing : maximum(payouts)
    max_loss = net_call_qty < 0 ? nothing : -minimum(payouts)
    return (max_profit, max_loss)
end

function compute_pnl(
        position::Position,
        chain::OptionChains.ChainState,
        multiplier::Float64 = _inferred_multiplier(position, chain)
)::PositionPnL
    unrealized = 0.0
    open_legs = _open_legs(position)
    for leg in open_legs
        current_mid = _chain_mid(chain, leg.conid)
        unrealized += (current_mid - leg.avg_fill_price) * leg.quantity * multiplier
    end
    realized = position.realized_pnl
    total = unrealized + realized
    max_profit, max_loss = _max_bounds(open_legs, multiplier)
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

function _interval_slope(
        legs::Vector{PositionLegRecord},
        left::Float64,
        right::Float64,
        multiplier::Float64
)::Float64
    probe = (left + right) / 2.0
    slope = 0.0
    for leg in legs
        strike = leg.strike::Float64
        right_symbol = leg.right::Symbol
        if _is_call(right_symbol)
            slope += (probe > strike ? leg.quantity : 0) * multiplier
        elseif _is_put(right_symbol)
            slope += (probe < strike ? -leg.quantity : 0) * multiplier
        end
    end
    return slope
end

function _push_unique!(roots::Vector{Float64}, x::Float64; atol::Float64 = 1e-8)
    x < 0.0 && return roots
    for existing in roots
        isapprox(existing, x; atol = atol) && return roots
    end
    push!(roots, x)
    return roots
end

function breakevens(position::Position, multiplier::Float64 = DEFAULT_OPTION_MULTIPLIER)::Vector{
    Float64}
    legs = _open_legs(position)
    _supports_payoff_math(legs) || return Float64[]
    strikes = sort(unique(leg.strike::Float64 for leg in legs))
    knots = unique(vcat(0.0, strikes))
    roots = Float64[]

    for idx in 1:(length(knots) - 1)
        left = knots[idx]
        right = knots[idx + 1]
        left_value = _position_value_at_expiry(legs, left, multiplier)
        right_value = _position_value_at_expiry(legs, right, multiplier)
        iszero(left_value) && _push_unique!(roots, left)
        iszero(right_value) && _push_unique!(roots, right)
        sign(left_value) == sign(right_value) && continue
        root = left + (0.0 - left_value) * (right - left) / (right_value - left_value)
        _push_unique!(roots, root)
    end

    if !isempty(knots)
        left = knots[end]
        left_value = _position_value_at_expiry(legs, left, multiplier)
        slope = _interval_slope(legs, left, left + 1.0, multiplier)
        if !iszero(slope)
            ray_root = left - left_value / slope
            ray_root > left && _push_unique!(roots, ray_root)
        elseif iszero(left_value)
            _push_unique!(roots, left)
        end
    end
    return sort(roots)
end

function breakevens(position::Position, chain::OptionChains.ChainState)::Vector{Float64}
    return breakevens(position, _inferred_multiplier(position, chain))
end
