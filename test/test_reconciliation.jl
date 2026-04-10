using Dates
using MarketState
using PositionManager
using Test
using UUIDs

function _event_leg(conid, action, qty, price)
    return PositionLeg(conid, string(conid), :call, 5200.0, Date(2026, 6, 19), action, qty, price, 0.0)
end

@testset "ExecutionSource creates and appends by order_id" begin
    store = PositionStore()
    event1 = PositionEvent(
        [_event_leg(1001, :buy, 1, 5.0)],
        "DU1",
        ExecutionSource,
        nothing,
        42,
        100,
        DateTime(2026, 4, 10, 12, 0, 0)
    )
    event2 = PositionEvent(
        [_event_leg(1002, :sell, 1, 2.0)],
        "DU1",
        ExecutionSource,
        nothing,
        42,
        100,
        DateTime(2026, 4, 10, 12, 0, 1)
    )
    apply_position_event!(store, event1)
    apply_position_event!(store, event2)
    @test length(load_open(store)) == 1
    @test length(only(load_open(store)).legs) == 2
end

@testset "PositionFeedSource unmatched goes to ungrouped" begin
    store = PositionStore()
    feed_event = PositionEvent(
        [_event_leg(3001, :buy, 1, 4.0)],
        "DU1",
        PositionFeedSource,
        nothing,
        nothing,
        nothing,
        DateTime(2026, 4, 10, 12, 0, 2)
    )
    apply_position_event!(store, feed_event)
    @test length(load_ungrouped(store)) == 1
end

@testset "partial and full close transitions" begin
    store = PositionStore()
    open_event = PositionEvent(
        [_event_leg(4001, :buy, 2, 3.0)],
        "DU1",
        ExecutionSource,
        nothing,
        88,
        100,
        DateTime(2026, 4, 10, 12, 0, 3)
    )
    apply_position_event!(store, open_event)
    pos = only(load_open(store))

    apply_partial_close!(store, pos.id, [_event_leg(4001, :sell, 1, 4.0)], 100.0)
    partial = store.positions[pos.id]
    @test partial.status == PartialClose
    @test partial.realized_pnl ≈ 100.0

    apply_partial_close!(store, pos.id, [_event_leg(4001, :sell, 1, 5.0)], 100.0)
    closed = store.positions[pos.id]
    @test closed.status == Closed
    @test closed.closed_at !== nothing
end

@testset "group_ungrouped! creates position and removes legs" begin
    store = PositionStore()
    store.ungrouped = [
        PositionLegRecord(5001, "5001", :call, 100.0, Date(2026, 6, 19), 1, 1.0, DateTime(
            2026,
            4,
            10,
            12,
            0,
            0
        )),
        PositionLegRecord(5002, "5002", :put, 100.0, Date(2026, 6, 19), -1, 1.0, DateTime(
            2026,
            4,
            10,
            12,
            0,
            0
        ))
    ]
    grouped = group_ungrouped!(store, [5001, 5002], "manual")
    @test length(grouped.legs) == 2
    @test isempty(store.ungrouped)
end

@testset "group_ungrouped! throws when no conids match" begin
    store = PositionStore()
    store.ungrouped = [PositionLegRecord(
        7001,
        "7001",
        :call,
        100.0,
        Date(2026, 6, 19),
        1,
        1.0,
        DateTime(2026, 4, 10, 12, 0, 0)
    )]
    @test_throws ArgumentError group_ungrouped!(store, [9999], "manual")
end
