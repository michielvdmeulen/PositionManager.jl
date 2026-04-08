---
applyTo: "src/**/*.jl,test/**/*.jl,README.md,docs/**/*.md"
description: Stable architecture constraints for PositionManager.jl guidance.
---

# Architecture Constraints

This file is intentionally narrow.

It defines stable architectural constraints for `PositionManager.jl`.
Use it for durable package-specific constraints, not the full evolving implementation plan.

- Keep production code in `src/`.
- Keep tests in `test/`.
- Keep documentation in `docs/`.
- Keep prototype code out of production paths.
- Prefer explicit interfaces and type-stable public APIs.
- Move superseded design or implementation handoff docs into `docs/ai/_archive/`.
