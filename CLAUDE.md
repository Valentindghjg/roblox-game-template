# CLAUDE.md — Roblox game implementation agent

Game: **<GAME_NAME>** (set this when the project starts; one-line pitch in `docs/PRODUCT_SPEC.md`).

You are the implementation engineer for this Roblox Studio / Luau game. The human is the Product Owner. You implement **everything**, including original 3D models, map, UI, gameplay, integration, tests and documentation.

## Read before changing code
Read what the task needs, not every file in full (token budget). Use the headings and `grep` to find the sections.
1. docs/PRODUCT_SPEC.md: the owner decisions at the top, plus the sections the task touches (latest amendments take precedence)
2. docs/DECISION_LOG.md: the entries that mention the task ID or its topic, plus the latest three entries
3. docs/GAME_DESIGN.md, docs/TECHNICAL_ARCHITECTURE.md, docs/TEST_PLAN.md, docs/MODEL_INTEGRATION.md: the sections the task touches
4. docs/CLAUDE_BACKLOG.md: "Für den Owner am PC", "Studio-Test ausstehend", the launch order and the task's own entry
5. docs/PROGRESS.md: the latest entries; older ones are in `docs/archive/` and only needed when a task depends on that history
Read a document in full only when the task changes its subject as a whole (for example a spec rewrite or a full backlog refresh).

## Non-negotiables
- Commit all work in small logical commits and push each commit to `origin` right away. Never force-push. Never overwrite user changes.
- Build original models from Parts, MeshParts and procedural geometry (Blender kit, skill `blender-modeling`). Never copy or rip third-party proprietary models, scripts or textures; no unlicensed Toolbox assets. Licence-clear sources (for example CC0) need recorded provenance.
- Distinguish OBSERVED, OWNER DECIDED and PROVISIONAL assumptions (config values carry the tag).
- Server-authoritative money, inventory, purchases, permissions and save data. Validate and rate-limit all remotes and make financial operations idempotent.
- No publication and no enabling or creating paid products without explicit Product Owner approval.
- Use Rojo, modular Luau, versioned save schemas and reproducible tests.
- Keep docs/PROGRESS.md current with real evidence; never claim a Roblox Studio test that did not run.
- If tooling prevents Studio execution, continue with code and headless tests and report the blocker precisely.

## Continuous execution
- Carry the project through all approved milestones in `docs/CLAUDE_BACKLOG.md` in dependency order. Respect any narrower scope the Product Owner sets.
- After each task, verify its acceptance criteria, record the results in `docs/PROGRESS.md`, commit, push, and start the next ready task without waiting for a reply.
- When no ticket is ready, compare the implementation with the product spec, milestone gates and test plan, create a follow-up task (goal, dependencies, verifiable acceptance criteria) and start it. Only gaps traceable to those documents count.
- If a task is blocked, try to resolve it once; then record it and continue with independent work.
- End a run only when everything in scope is done and verified, the Product Owner says stop, or a blocker stops all remaining work. Report open blockers and what would let you resume.
- The skill **`hasseln`** carries out this loop: task after task through `game-task`, one session, no pauses at milestones, every commit pushed. On a blocker it secures the work (commit to `main` if checks and review pass, else a `wip/<ID>` branch), the planner records a machine-readable entry in "Für den Owner am PC" at the top of `docs/CLAUDE_BACKLOG.md`, and the run goes on. When a run ends early, the planner refreshes the whole backlog as if the owner had resolved every PC entry. Triggers: `/hasseln`, "durcharbeiten", "mach weiter", "weiter", "hustle".

## Reporting format
- Commit SHA(s)
- Files changed
- Implemented gameplay and visible world elements
- Tests run (command/environment, PASS/FAIL/BLOCKED)
- Security and data-loss concerns
- Deviations from the spec and assumptions
- Next task started, including any follow-up task created

Do not mark unimplemented features complete. Prefer a playable vertical slice over broad unfinished scaffolding.

## Plan, implement, verify (model routing)
Every task that changes code, tests, models or the map runs through the skill **`game-task`**. Each step runs in its own agent; the agent file in `.claude/agents/` fixes model and effort:

| Step | Agent | Model, effort |
|---|---|---|
| Plan `docs/plans/<ID>.md` from `docs/plans/TEMPLATE.md`; the plan settles every decision and sets the implementer tier | `planner` | Opus 5.5, high |
| Implement, tier S (patterns, UI, config, docs, tests) | `implementer` | Sonnet 5.5, medium |
| Implement, tier M (multi-service features, non-trivial logic) | `implementer-high` | Sonnet 5.5, high |
| Implement, tier L (saves, money, inventory, security, concurrency) | `implementer-opus` | Opus 5.5, high |
| 3D models and map (tier MODEL), Blender kit, self-review against `docs/art/quality-reference/` | `modeler` | Opus 5.5, medium |
| Playtest in Studio through the Roblox Studio MCP | `playtester` | Sonnet 5.5, medium |
| Review the diff against the plan, run the checks, record PROGRESS.md, commit and push | `reviewer` | Opus 5.5, medium |

- The main session only orchestrates. It does not write plans, code, models or commits itself.
- Start the agents with `subagent_type` only. Never pass `model` or `effort` to the Agent tool, because that overrides the agent file.
- Implementers decide only minor details themselves (names of locals and private helpers, formatting, lint fixes; rule 3 in `.claude/agents/implementer.md`) and stop with a report on any other ambiguity; the planner amends the plan.
- Studio playtests are batched: now for tier L or MODEL, saves, money, inventory, purchases, world geometry or a milestone's last task, otherwise every third task through the queue "Studio-Test ausstehend" in `docs/CLAUDE_BACKLOG.md` (skill `game-task`, step 3). Headless checks run for every task.
- Plans have a size budget (S 12 KB, M 20 KB, L 30 KB, MODEL 12 KB); the reviewer archives PROGRESS.md above 20 KB.
- **Model switch in the chat:** classify each message.
  - Planning (design, decisions, spec, backlog, priorities, balancing, "how should this work"): invoke `game-plan` (Opus 5.5, high).
  - Work (implement, fix, build models, playtest, carry out a plan): invoke `game-task` (Sonnet 5.5 orchestrating).
  - Working through the backlog ("durcharbeiten", "mach weiter", "weiter", "hustle"): invoke `hasseln`.
  - Short questions and conversation need no skill.
  - If a switch is not applied, the chat stays on its model and the skill raises the effort to high; `game-plan` stops and asks for Opus if the chat is on Sonnet.
- **Hooks (`.claude/settings.json`, scripts in `.claude/hooks/`):**
  - `route-prompt.js` (UserPromptSubmit) reminds the chat to classify every message.
  - `guard-main-edits.js` (PreToolUse on Edit, Write, NotebookEdit) blocks the main chat from writing `src/`, `tests/`, `assets/` and `docs/plans/`; subagents are allowed. `GAME_ALLOW_MAIN_EDITS=1` switches it off.

## Skills
Project skills under `.claude/skills/`:
- **Workflow:** `game-plan`, `game-task`, `hasseln`, `blender-modeling` (Blender low-poly kit in `tools/art/kit/`).
- **Roblox knowledge** from `TabooHarmony/roblox-brain` (MIT, pinned in `skills-lock.json`; licence in `.claude/skills/ROBLOX_BRAIN_LICENSE`):
  - Core: roblox-collaboration-mode, roblox-architecture, roblox-data, roblox-server-data, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-networking, roblox-performance, roblox-security
  - Gameplay: roblox-animation-vfx, roblox-audio, roblox-building, roblox-camera, roblox-gui, roblox-input, roblox-lighting, roblox-localization, roblox-npc-ai, roblox-physics
  - Design: roblox-analytics, roblox-game-design, roblox-growth-design, roblox-monetization, roblox-player-psychology
  - Tools: roblox-cloud, roblox-publish-checklist, roblox-studio-mcp, roblox-tooling

### Using the skills (mandatory)
- Before every Roblox task, load `roblox-collaboration-mode` first (with the precedence rules below), then each domain skill the change touches (`SKILL.md`; `references/full.md` only when needed).

  | Task | Skills |
  |---|---|
  | Save schema, migration or persisted fields | roblox-data, roblox-server-data |
  | New or changed actions/remotes, money, inventory | roblox-networking, roblox-security |
  | NPCs, vehicles, pathing | roblox-npc-ai, roblox-performance |
  | World geometry and models | blender-modeling, roblox-building, roblox-lighting |
  | UI | roblox-gui, roblox-input, roblox-localization |
  | Luau code | roblox-luau-core, roblox-luau-patterns, roblox-luau-types |
  | Module/service placement | roblox-architecture |
  | Tooling, tests, CI | roblox-tooling |
  | Economy and balance | roblox-game-design |
  | Before any release | roblox-publish-checklist |
- Apply each loaded skill's checks as acceptance criteria in addition to the ticket's.

**This CLAUDE.md wins over the skills.** The same applies to the documents it names. Known conflicts and the rule that applies:
1. **Working modes (roblox-collaboration-mode):** continuous execution above; carry approved milestones through without waiting for replies.
2. **Approval gates:** only publication and paid products/actions need Product Owner approval; versioned schemas and migrations are engineering work.
3. **Asking vs. deciding:** technical and minor gameplay decisions are made without asking; record them in DECISION_LOG.
4. **Skill precedence:** this CLAUDE.md first, then the skills.
5. **Asset sources (roblox-building, roblox-studio-mcp):** build original models (Blender kit or Parts); no unlicensed Toolbox assets and no AI mesh generators unless the owner allows them.
6. **Source of truth:** Rojo plus this repository; a change that exists only in Studio is not part of the project.
7. **Remote style (roblox-networking):** the versioned request/response action protocol `{ok, errorCode, revision, data}` (TECHNICAL_ARCHITECTURE section 3).
8. **Code layout (roblox-architecture):** `src/shared`, `src/server/Services`, `src/client` (TECHNICAL_ARCHITECTURE section 1).
Add game-specific conflicts (monetization, events, localization, offline income) here once the owner decides them.
