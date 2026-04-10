using Dates
using PositionManager
using Test
using UUIDs

@testset "Position types and defaults" begin
    leg = PositionLegRecord(
        1001,
        "1001",
        :call,
        5200.0,
        Date(2026, 6, 19),
        1,
        5.0,
        DateTime(2026, 4, 10, 10, 0, 0)
    )
    position = Position(; id = uuid4(), legs = [leg], campaign = "default")
    @test position.status == Open
    @test position.realized_pnl == 0.0
end
