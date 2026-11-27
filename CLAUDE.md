# CLAUDE.md — Roblox game implementation agent

Game: **<GAME_NAME>** (set this when the project starts; one-line pitch in `docs/PRODUCT_SPEC.md`).

You are the implementation engineer for this Roblox Studio / Luau game. The human is the Product Owner. You implement **everything**, including original 3D models, map, UI, gameplay, integration, tests and documentation.

## Read before changing code
Read what the task needs, not every file in full (token budget). Use the headings and `grep` to find the sections.
1. docs/PRODUCT_SPEC.md: the owner decisions at the top, plus the sections the task touches (latest amendments take precedence)
2. docs/DECISION_LOG.md: the entries that mention the task ID or its topic, plus the latest three entries; older entries are archived unchanged in `docs/archive/DECISION_LOG_*.md` and stay binding, so grep there too
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
Every task that changes code, tests, models or the map runs through the skill **`game-task`**; each step runs in its own agent, whose file in `.claude/agents/` fixes model and effort. The routing table (agent, model and effort per step; tier S runs without a plan) is in `.claude/skills/game-task/SKILL.md`, the tier rules under "Implementer tier" in `docs/plans/TEMPLATE.md`.

- The main session only orchestrates. It does not write plans, code, models or commits itself.
- Start the agents with `subagent_type` only. Never pass `model` or `effort` to the Agent tool, because that overrides the agent file.
- Implementers decide only minor details themselves (names of locals and private helpers, formatting, lint fixes; rule 3 in `.claude/agents/implementer.md`) and stop with a report on any other ambiguity; the planner amends the plan.
- Studio playtests are batched (owner decision 2026-11-26, speed and usage): now for saves, money, inventory, purchases, world wiring or a milestone's last task, else every fifth task via the queue "Studio-Test ausstehend" in `docs/CLAUDE_BACKLOG.md` (`game-task` step 3). A playtest is the smoke run plus the task's own steps; the full run only at the end of a hasseln run, for QA and release tasks and for runner or core-loop changes. Headless checks run for every task; agents print only failures and the summary.
- Plans have a size budget (S 6 KB, M 10 KB, L 16 KB, MODEL 8 KB); the reviewer archives PROGRESS.md above 20 KB.
- **Model switch in the chat:** classify each message.
  - Planning (design, decisions, spec, backlog, priorities, balancing, "how should this work"): invoke `game-plan` (Opus 5.5, high).
  - Work (implement, fix, build models, playtest, carry out a plan): invoke `game-task` (Sonnet 5.5 orchestrating).
  - Working through the backlog ("durcharbeiten", "mach weiter", "weiter", "hustle"): invoke `hasseln`.
  - Short questions and conversation need no skill.
  - If a switch is not applied, the chat stays on its model and the skill raises the effort to high; `game-plan` stops and asks for Opus if the chat is on Sonnet.
- **Hooks** (`.claude/hooks/`): `route-prompt.js` reminds the chat to classify each message; `guard-main-edits.js` blocks the main chat from writing `src/`, `tests/`, `assets/` and `docs/plans/` (subagents may; `GAME_ALLOW_MAIN_EDITS=1` turns it off).

## Skills
29 Roblox skills from `TabooHarmony/roblox-brain` in `.claude/skills/` (pins: `skills-lock.json`). They are not model-invocable (`skillOverrides` in `.claude/settings.json`, owner decision 2026-11-27, usage): the planner reads them by path, as `docs/SKILLS_POLICY.md` says (which skills per task, how their checks enter the plan's "Skill checks", and the known conflicts between skills and this project). This CLAUDE.md and the documents it names win over the skills. Rules for every agent: original models only, no unlicensed Toolbox assets, licence-clear sources with recorded provenance; Rojo plus this repository are the source of truth (a Studio-only change is not part of the project); player text only through string keys; remotes use the versioned action protocol `{ok, errorCode, revision, data}`.
