# Test plan

## 1. Quality gates
- G0: `stylua --check src tests tools`, `selene src tests tools`, `luau-lsp analyze` on the typed modules, `lune run tests/headless/run.luau`, `rojo build` of both projects, `lune run tests/tools/art_pipeline.luau` (CI: `.github/workflows/quality.yml`).
- G1: the plan's Studio playtest steps pass (playtester, through the Roblox Studio MCP).

## 2. Unit tests
Cases live in `tests/studio/Cases/<Name>_Test.lua` and run headless and in Studio. New modules in `src/shared` and `src/server/Services` are discovered automatically.

## 3. Studio playtests
Driven by the `playtester` agent. Batched (CLAUDE.md): now for risky tasks, otherwise every third task.

### Repeatable run
<Once the game has a core loop, add a Studio-only test hook and a script that plays the whole loop and prints PASS/FAIL per step; describe how to start it here.>

## 4. Budgets
Server heartbeat ≥ 55 FPS with the planned player and NPC count; mobile memory and draw calls within Roblox guidance.
