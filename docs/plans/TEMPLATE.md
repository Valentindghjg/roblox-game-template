# <ID> — <title>

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Haiku 5.5). Reviewed and committed by: `reviewer` (Sonnet 5.5, high). Pipeline: skill `game-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
One or two sentences: what the player can do afterwards.

## Source of truth
Spec sections, reference observations (`docs/references/…`) and owner decisions this plan implements.

## Implementer tier
Tier: S | M | L | MODEL (keep exactly one). Reason: one line.

- **S** → `implementer` (Sonnet 5.5, medium): follows existing patterns; UI, localization, config values, docs, tests or a small feature. No change to the save schema, money, inventory, purchases or remote validation.
- **M** → `implementer-high` (Sonnet 5.5, high): a feature across several services or non-trivial logic (NPC pathing, timers, state machines, world generation), with the same exclusions as S.
- **L** → `implementer-opus` (Opus 5.5, high): save schema or migration, DataStore or session locks, money, inventory or purchases, remote validation or rate limits, concurrency, or a bug whose cause is not yet known.
- **MODEL** → `modeler` (Opus 5.5, medium): 3D models and map geometry. Also set the **quality tier** for every model, using the rules in `docs/art/quality-reference/README.md`:
  - A: seen often or for long, such as the stand and HQ, cars, truck, buildings and trees for sale.
  - B: small, distant or rare.

If several tiers fit, the highest wins (L > M > S). A model task that also needs code changes becomes two plans.

## Skills to load
For example: roblox-data, roblox-networking, roblox-security, roblox-gui.

## Files
| File | New/Change | Purpose |
|---|---|---|

## Data and config
Exact config keys with values and evidence tags (OBSERVED/PROVISIONAL), schema fields, migration steps.

## Steps
1. Exact change, with function names and signatures, error codes and strings (English).
2. …

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|

## Playtest (Studio, via playtester)
1. Setup.
2. Action → expected result (values to read back, objects that must exist).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (expected count), `rojo build`.
- Behaviour criteria from the backlog ticket.

## Out of scope
What this plan deliberately does not do.
