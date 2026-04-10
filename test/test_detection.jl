using Dates
using PositionManager
using Test

_leg(conid, right, strike, expiry, qty) = PositionLegRecord(
    conid,
    string(conid),
    right,
    strike,
    expiry,
    qty,
    1.0,
    DateTime(2026, 4, 10, 10, 0, 0)
)

@testset "single and two-leg detection" begin
    expiry = Date(2026, 6, 19)
    @test detect_strategy([_leg(1, :call, 5200.0, expiry, 1)]) == "long_call"
    @test detect_strategy([_leg(1, :call, 5200.0, expiry, -1)]) == "short_call"
    @test detect_strategy([_leg(2, :put, 5100.0, expiry, 1), _leg(3, :put, 5200.0, expiry, -1)]) ==
          "put_vertical"
    @test detect_strategy([_leg(4, :put, 5100.0, expiry, 1), _leg(5, :call, 5200.0, expiry, 1)]) ==
          "strangle"
    @test detect_strategy([_leg(4, :put, 5100.0, expiry, -1), _leg(5, :call, 5100.0, expiry, -1)]) ==
          "short_straddle"
end

@testset "butterfly detection and incremental assembly" begin
    expiry = Date(2026, 6, 19)
    l1 = _leg(10, :put, 5000.0, expiry, 1)
    l2 = _leg(11, :put, 5100.0, expiry, -2)
    l3 = _leg(12, :put, 5200.0, expiry, 1)
    @test detect_strategy([l1]) == "long_put"
    @test detect_strategy([l1, l2]) == "put_vertical"
    @test detect_strategy([l1, l2, l3]) == "put_butterfly_1x2x1"
end
