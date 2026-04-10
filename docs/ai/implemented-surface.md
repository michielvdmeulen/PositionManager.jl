# PositionManager Implemented Surface

Last changed: 2026-04-10T18:05:00+02:00

## Package role

`PositionManager.jl` provides an in-memory position model for grouped option/futures legs,
strategy-shape detection, position P&L calculations, and reconciliation handlers driven by
`MarketState.PositionEvent`.

## Public surface

Types:

- `PositionLegRecord`
- `PositionStatus` (`Open`, `PartialClose`, `Closed`)
- `Position`
- `PositionPnL`
- `AbstractPositionStore`
- `PositionStore`

Store APIs:

- `save!(store, position)`
- `load_open(store)`
- `load_ungrouped(store)`
- `save_ungrouped!(store, legs)`

Core logic:

- `detect_strategy(legs)`
- `compute_pnl(position, chain, multiplier=inferred_from_chain_or_default)`
- `breakevens(position, multiplier=100.0)`
- `breakevens(position, chain)` (uses inferred chain multiplier)
- `apply_position_event!(store, event)`
- `apply_partial_close!(store, position_id, closing_legs, multiplier=100.0)`
- `group_ungrouped!(store, conids, campaign="default")`

## Current constraints

- Persistence is in-memory only (`PositionStore`).
- No PostgreSQL backend yet.
- No campaign-budget model integration yet.
- Payoff bounds and breakevens are now derived from generic piecewise payoff math across
  option legs, rather than strategy-label-specific shortcuts.
