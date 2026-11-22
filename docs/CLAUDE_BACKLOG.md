# Backlog

## Für den Owner am PC
Blockers only the owner can resolve (Studio, Rojo plugin, access, keys, decisions). Written by the `planner` during `hasseln` in the fixed format from `.claude/skills/hasseln/SKILL.md`; the next run checks each entry's `Prüfen` field first and starts with its `Danach` task.

_Keine offenen Einträge._

#### Erledigt
_Noch keine._

## Studio-Test ausstehend
Tasks committed with "Studio: deferred (batch)" (skill `game-task`, step 3). The third entry triggers a batch run.

_Leer._

## How to work
- Task IDs are planning IDs (for example G-01). Each task: goal, dependencies, verifiable acceptance criteria, tier hint.
- Work in launch order, then dependency order. Publication and paid actions need owner approval.

## Launch order
_Written by the planner in the first planning session._

## P0 — Foundation
- [ ] **G-01 Project setup check** · S · Depends: none. Accept: `rokit install` works, CI `Quality` passes on main, `rojo serve` connects in Studio, `lune run tools/art/art.luau doctor` finds Blender.

## P1 — Playable core
_Tasks from the first planning session._

## Milestone gates
- P0: tools, unit tests, safe persistence and network foundation.
- P1: the core loop playable in Studio, with save and rejoin.
