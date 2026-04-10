struct PositionLegRecord
    conid::Int
    symbol::String
    right::Union{Symbol, Nothing}
    strike::Union{Float64, Nothing}
    expiry::Union{Date, Nothing}
    quantity::Int
    avg_fill_price::Float64
    open_timestamp::DateTime
end

@enum PositionStatus::UInt8 Open PartialClose Closed

struct Position
    id::UUID
    legs::Vector{PositionLegRecord}
    campaign::String
    strategy_label::Union{String, Nothing}
    status::PositionStatus
    opened_at::DateTime
    closed_at::Union{DateTime, Nothing}
    notes::Union{String, Nothing}
    realized_pnl::Float64
end

function Position(;
        id::UUID = uuid4(),
        legs::AbstractVector{PositionLegRecord},
        campaign::AbstractString = "default",
        strategy_label::Union{String, Nothing} = nothing,
        status::PositionStatus = Open,
        opened_at::DateTime = Dates.now(),
        closed_at::Union{DateTime, Nothing} = nothing,
        notes::Union{String, Nothing} = nothing,
        realized_pnl::Real = 0.0
)
    return Position(
        id,
        collect(legs),
        String(campaign),
        strategy_label,
        status,
        opened_at,
        closed_at,
        notes,
        Float64(realized_pnl)
    )
end

struct PositionPnL
    unrealized::Float64
    realized::Float64
    total::Float64
    max_profit::Union{Float64, Nothing}
    max_loss::Union{Float64, Nothing}
    pct_of_max_profit::Union{Float64, Nothing}
    pct_of_max_loss::Union{Float64, Nothing}
end
