using Dates
using OptionChains
using PositionManager
using Test

function _chain_with_quotes(entries::Vector{Tuple{Int, Float64, Float64}}; multiplier::Float64 = 100.0)
    nodes = OptionNode[]
    for (conid, _, _) in entries
        push!(
            nodes,
            OptionNode(
                ticker = string(conid),
                expiry = Date(2026, 6, 19),
                right = Call,
                strike = 100.0 + conid,
                underlying = "ES",
                multiplier = multiplier
            )
        )
    end
    state = initialize_state(OptionUniverse(nodes))
    for (idx, (_, bid, ask)) in enumerate(entries)
        apply_quote_update!(
            state,
            idx,
            QuoteSnapshot(
                bid = bid,
                ask = ask,
                timestamp = DateTime(2026, 4, 10, 11, 0, 0)
            )
        )
    end
    return state
end

@testset "compute_pnl and breakevens" begin
    expiry = Date(2026, 6, 19)
    legs = [
        PositionLegRecord(1, "1", :call, 100.0, expiry, 1, 2.0, DateTime(2026, 4, 10, 10, 0, 0)),
        PositionLegRecord(2, "2", :call, 110.0, expiry, -1, 1.0, DateTime(2026, 4, 10, 10, 0, 0))
    ]
    pos = Position(; legs = legs, campaign = "default")
    chain = _chain_with_quotes([(1, 3.0, 3.0), (2, 0.5, 0.5)])
    pnl = compute_pnl(pos, chain, 100.0)
    @test pnl.unrealized ≈ ((3.0 - 2.0) * 1 + (0.5 - 1.0) * -1) * 100.0
    @test pnl.max_profit !== nothing
    @test pnl.max_loss !== nothing
    @test length(breakevens(pos, 100.0)) == 1
end

@testset "compute_pnl infers multiplier from chain node metadata" begin
    expiry = Date(2026, 6, 19)
    legs = [PositionLegRecord(
        7,
        "7",
        :call,
        100.0,
        expiry,
        1,
        2.0,
        DateTime(2026, 4, 10, 10, 0, 0)
    )]
    pos = Position(; legs = legs, campaign = "default")
    chain = _chain_with_quotes([(7, 3.0, 3.0)]; multiplier = 50.0)
    pnl = compute_pnl(pos, chain)
    @test pnl.unrealized ≈ (3.0 - 2.0) * 50.0
end

@testset "single long put has finite max profit and one breakeven" begin
    expiry = Date(2026, 6, 19)
    legs = [PositionLegRecord(
        9,
        "9",
        :put,
        100.0,
        expiry,
        1,
        4.0,
        DateTime(2026, 4, 10, 10, 0, 0)
    )]
    pos = Position(; legs = legs, campaign = "default")
    chain = _chain_with_quotes([(9, 3.0, 3.0)])
    pnl = compute_pnl(pos, chain, 100.0)
    @test pnl.max_profit ≈ (100.0 - 4.0) * 100.0
    @test pnl.max_loss ≈ 4.0 * 100.0
    @test breakevens(pos, 100.0) == [96.0]
end

@testset "missing chain leg does not throw" begin
    leg = PositionLegRecord(
        999,
        "999",
        :call,
        100.0,
        Date(2026, 6, 19),
        1,
        1.0,
        DateTime(2026, 4, 10, 10, 0, 0)
    )
    pos = Position(; legs = [leg], campaign = "default")
    chain = _chain_with_quotes([(1, 1.0, 1.0)])
    pnl = compute_pnl(pos, chain, 100.0)
    @test pnl.unrealized == (0.0 - 1.0) * 100.0
end
