using PositionManager
using SafeTestsets
using Test

@safetestset "Types" begin
    include("test_types.jl")
end

@safetestset "Detection" begin
    include("test_detection.jl")
end

@safetestset "PnL" begin
    include("test_pnl.jl")
end

@safetestset "Reconciliation" begin
    include("test_reconciliation.jl")
end
