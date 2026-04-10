module PositionManager

using Dates
using UUIDs

import MarketState
import OptionChains

include("types.jl")
include("store.jl")
include("detection.jl")
include("pnl.jl")
include("reconciliation.jl")

export PositionLegRecord,
       PositionStatus,
       Open,
       PartialClose,
       Closed,
       Position,
       PositionPnL
export AbstractPositionStore,
       PositionStore,
       save!,
       load_open,
       load_ungrouped,
       save_ungrouped!
export detect_strategy, compute_pnl, breakevens
export apply_position_event!, apply_partial_close!, group_ungrouped!

end
