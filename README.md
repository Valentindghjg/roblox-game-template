# Roblox Game Template for Claude Code

A ready-to-use starting point for building Roblox games with [Claude Code](https://claude.com/claude-code) as the developer: rules, specialised agents, skills, hooks, a Blender-to-Roblox art pipeline, a headless test runner and CI. It contains no game, only the setup, so every new game starts with a working workflow from minute one.

🇩🇪 Deutsche Kurzanleitung: [README.de.md](README.de.md)

## Why
Letting an AI write a whole game usually fails in three places: it forgets decisions, it spends tokens re-reading everything, and nobody checks its work in the engine. This template fixes that with a fixed pipeline:

- **Every task is planned, implemented, playtested and reviewed by separate agents**, each on the model that fits the job (Opus plans and guards money and saves, Sonnet writes the everyday code).
- **Decisions live in files** (`docs/`), so a new session picks up exactly where the last one stopped.
- **Token budgets are built in:** agents read only the sections a task needs, plans have size limits, logs archive themselves.
- **Work is verified:** headless unit tests on every task, Studio playtests through the Roblox Studio MCP, a reviewer that runs all checks before it commits and pushes.
- **It keeps going on its own:** say "hasseln" and Claude works through the backlog task by task, records anything only you can fix in a checklist, and continues with the next task.

## What's inside
| Path | What it does |
|---|---|
| `CLAUDE.md` | The rulebook: non-negotiables (server authority, no paid products without approval, original art), model routing, skill table, conflict rules |
| `.claude/agents/` | `planner`, `implementer` (tiers S, M, L), `modeler`, `playtester`, `reviewer`, each with a pinned model and effort |
| `.claude/skills/game-plan` | Planning sessions on Opus: spec, decisions, backlog |
| `.claude/skills/game-task` | One task through the full pipeline: plan → implement → playtest → review → commit → push |
| `.claude/skills/hasseln` | Works through the whole backlog without stopping; handles blockers and batched Studio tests |
| `.claude/skills/blender-modeling` | How the modeler builds low-poly models in Blender with the kit, plus style rules and budgets |
| `.claude/skills/roblox-*` | 29 Roblox skills from [TabooHarmony/roblox-brain](https://github.com/TabooHarmony/roblox-brain) (MIT): data, networking, security, UI, NPCs, performance, monetization and more |
| `.claude/hooks/` | A reminder on every message to route it to the right skill, and a guard that stops the main chat from editing code directly |
| `.mcp.json` | Roblox Studio MCP server, so agents can playtest in Studio |
| `tools/art/` | Art pipeline: Blender `.blend` → FBX → Open Cloud upload → normalised `.rbxm` that Rojo syncs; `kit/lowpoly_kit.py` with building blocks (boxes, planks, roofs with snow, firs, string lights, wheels…) |
| `tests/` | Headless runner (Lune) that discovers modules and test cases automatically, Studio test runner, art pipeline tests |
| `docs/` | Templates: product spec, game design, architecture, test plan, backlog, decision log, plan template, model quality reference |
| `.github/workflows/quality.yml` | CI: StyLua, Selene, luau-lsp, unit tests, Rojo builds, art pipeline tests |

## Requirements
- [Roblox Studio](https://create.roblox.com/) with the [Rojo plugin](https://rojo.space/) and Roblox's Studio MCP server enabled (see the Roblox Creator docs for "Studio MCP"; `.mcp.json` already points at its default install location).
- [Claude Code](https://claude.com/claude-code) (CLI or desktop app).
- [Rokit](https://github.com/rojo-rbx/rokit) – installs the pinned Rojo, Selene, StyLua, luau-lsp and Lune.
- [Node.js](https://nodejs.org/) – runs the hooks.
- [Blender 5.x](https://www.blender.org/) – only for 3D models.

## Tutorial: from zero to your first playable feature

### 1. Create your game repository
Click **Use this template → Create a new repository** on GitHub, or:
```powershell
gh repo create MyGame --private --template Valentindghjg/roblox-game-template --clone
```
```powershell
cd MyGame
```
```powershell
rokit install
```

### 2. Name the game
- In `CLAUDE.md`, replace `<GAME_NAME>` in the line `Game: **<GAME_NAME>**`.
- In `default.project.json` and `release.project.json`, set `"name"`.

### 3. Connect Studio
```powershell
rojo serve default.project.json
```
Open an empty place in Roblox Studio and press **Connect** in the Rojo plugin. Start Claude Code in the repository folder; it finds the Studio MCP through `.mcp.json`.

### 4. Plan the game with Claude
Tell Claude something like: *"Let's plan the game: a cosy fishing village where you catch, sell and upgrade."*
The `game-plan` skill switches to Opus and works through the important questions with you. It writes the answers to `docs/PRODUCT_SPEC.md` (your decisions), `docs/GAME_DESIGN.md` (mechanics and numbers) and `docs/CLAUDE_BACKLOG.md` (tasks with acceptance criteria and a launch order). Only you decide publication, paid products and anything the spec leaves open; Claude decides technical details and records them in `docs/DECISION_LOG.md`.

### 5. Let it work
Say **"hasseln"** (or `/hasseln`, "weiter", "mach weiter"). For every task:
1. `planner` writes `docs/plans/<ID>.md` and picks a tier.
2. The matching implementer writes code and tests (S/M on Sonnet, L on Opus for saves, money and security).
3. `playtester` tests it in Studio (right away for risky tasks, otherwise batched every third task).
4. `reviewer` runs all checks, updates `docs/PROGRESS.md`, commits and pushes.

You can watch, stop it anytime, or do something else.

### 6. Fix what only you can fix
When the run hits something it cannot solve (Studio closed, a missing API key, a decision that is yours), it saves its work and adds an entry to **"Für den Owner am PC"** at the top of `docs/CLAUDE_BACKLOG.md`: what is wrong, your steps, how it will check, and which task runs next. Resolve the entries, say "weiter", and it continues exactly there.

### 7. Make 3D models
The `modeler` writes a Blender Python script per model using `tools/art/kit/lowpoly_kit.py`, builds it headless, renders previews and compares them with your reference images in `docs/art/quality-reference/` before it is done. Try the kit yourself:
```powershell
blender -b --factory-startup --python tools/art/kit/examples/market_stall.py -- --out assets/art/source/Props/Demo/model.blend
```
To upload models into your game, set up the Open Cloud key (next section). Without it, models are still built and rendered; only the upload waits.

### 8. Check everything locally
```powershell
lune run tests/headless/run.luau
```
```powershell
selene src tests tools
```
```powershell
stylua --check src tests tools
```
New modules in `src/shared` and `src/server/Services` and new test cases in `tests/studio/Cases/<Name>_Test.lua` are picked up automatically.

## Art pipeline setup
1. On [create.roblox.com](https://create.roblox.com/) → Open Cloud → API Keys, create a key with **Assets: read and write** for your account or group.
2. Set the environment variables `ROBLOX_OPEN_CLOUD_API_KEY` and `ART_CREATOR` (`user:<id>` or `group:<id>`).
3. `lune run tools/art/art.luau doctor` should report ok. Then `lune run tools/art/art.luau build <artPath>` exports, uploads and normalises a model.

## Customising
- **Palette:** `src/shared/ArtPalette.lua` (the kit's examples use winter colours; replace them with your game's).
- **Taste:** describe the models you like and dislike in `docs/art/quality-reference/README.md`.
- **Rules:** add game-specific rules (monetization, events, languages) to the conflict list in `CLAUDE.md`.
- **Models per role:** change `model` and `effort` in `.claude/agents/*.md`.

## Folder layout
```
src/shared            -> ReplicatedStorage.Shared   (pure modules, config, protocol)
src/server            -> ServerScriptService.Server (main.server.lua + Services/)
src/client            -> StarterPlayerScripts.Client
assets/art/rbxm       -> ReplicatedStorage.ArtAssets
tests/studio          -> ServerStorage.UnitTest      (left out of release.project.json)
```

## Credits
- Roblox skills: [TabooHarmony/roblox-brain](https://github.com/TabooHarmony/roblox-brain), MIT licence (`.claude/skills/ROBLOX_BRAIN_LICENSE`).
- Toolchain: [Rojo](https://rojo.space/), [Rokit](https://github.com/rojo-rbx/rokit), [Selene](https://github.com/Kampfkarren/selene), [StyLua](https://github.com/JohnnyMorganz/StyLua), [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp), [Lune](https://github.com/lune-org/lune).
