function _strategy_legs(legs::AbstractVector{PositionLegRecord})
    return filter(leg -> !iszero(leg.quantity), legs)
end

function _all_options(legs::AbstractVector{PositionLegRecord})::Bool
    return all(leg -> leg.right !== nothing && leg.strike !== nothing && leg.expiry !== nothing, legs)
end

function _single_leg_label(leg::PositionLegRecord)::Union{String, Nothing}
    leg.right === :call && return leg.quantity > 0 ? "long_call" : "short_call"
    leg.right === :put && return leg.quantity > 0 ? "long_put" : "short_put"
    return nothing
end

function _same_expiry(legs::AbstractVector{PositionLegRecord})::Bool
    isempty(legs) && return true
    expiry = legs[1].expiry
    return all(leg -> leg.expiry == expiry, legs)
end

function _opposite_sign(a::Int, b::Int)::Bool
    return sign(a) != sign(b)
end

function _two_leg_label(legs::AbstractVector{PositionLegRecord})::Union{String, Nothing}
    length(legs) == 2 || return nothing
    l1, l2 = legs
    same_expiry = l1.expiry == l2.expiry

    if same_expiry && l1.right == :call && l2.right == :call && l1.strike != l2.strike &&
       _opposite_sign(l1.quantity, l2.quantity)
        return "call_vertical"
    end
    if same_expiry && l1.right == :put && l2.right == :put && l1.strike != l2.strike &&
       _opposite_sign(l1.quantity, l2.quantity)
        return "put_vertical"
    end
    if same_expiry && Set([l1.right, l2.right]) == Set([:put, :call])
        put_leg = l1.right == :put ? l1 : l2
        call_leg = l1.right == :call ? l1 : l2
        if put_leg.quantity > 0 && call_leg.quantity > 0
            return put_leg.strike == call_leg.strike ? "straddle" :
                   put_leg.strike < call_leg.strike ? "strangle" : nothing
        elseif put_leg.quantity < 0 && call_leg.quantity < 0
            return put_leg.strike == call_leg.strike ? "short_straddle" :
                   put_leg.strike < call_leg.strike ? "short_strangle" : nothing
        end
    end
    if l1.right == :put && l2.right == :put && l1.expiry != l2.expiry &&
       _opposite_sign(l1.quantity, l2.quantity)
        return "put_calendar"
    end
    if l1.right == :call && l2.right == :call && l1.expiry != l2.expiry &&
       _opposite_sign(l1.quantity, l2.quantity)
        return "call_calendar"
    end
    return nothing
end

function _butterfly_label(legs::AbstractVector{PositionLegRecord})::Union{String, Nothing}
    length(legs) == 3 || return nothing
    _same_expiry(legs) || return nothing
    rights = Set(leg.right for leg in legs)
    length(rights) == 1 || return nothing
    right = first(rights)
    right in (:call, :put) || return nothing

    ordered = sort(collect(legs); by = leg -> leg.strike)
    q1, q2, q3 = ordered[1].quantity, ordered[2].quantity, ordered[3].quantity
    q1 > 0 || return nothing
    q3 > 0 || return nothing
    q2 < 0 || return nothing
    abs(q1) == abs(q3) || return nothing
    isapprox(ordered[2].strike - ordered[1].strike, ordered[3].strike - ordered[2].strike;
        atol = 0.01) || return nothing
    n = abs(q1)
    m = abs(q2)
    prefix = right == :call ? "call_butterfly" : "put_butterfly"
    return "$(prefix)_$(n)x$(m)x$(n)"
end

function detect_strategy(legs::Vector{PositionLegRecord})::Union{String, Nothing}
    open_legs = _strategy_legs(legs)
    isempty(open_legs) && return nothing
    _all_options(open_legs) || return nothing

    if length(open_legs) == 1
        return _single_leg_label(open_legs[1])
    elseif length(open_legs) == 2
        return _two_leg_label(open_legs)
    elseif length(open_legs) == 3
        return _butterfly_label(open_legs)
    end
    return nothing
end
