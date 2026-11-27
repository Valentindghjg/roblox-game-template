# Skills policy

Moved here from `CLAUDE.md` unchanged (owner decision 2026-11-27, usage: `CLAUDE.md` is sent with every request and every agent start). The planner reads this file for every plan; the main chat reads it when planning (`cm2-plan`/`game-plan`). It binds as `CLAUDE.md` does.

## Skills
Project skills under `.claude/skills/`:
- **Workflow:** `game-plan`, `game-task`, `hasseln`, `blender-modeling` (Blender low-poly kit in `tools/art/kit/`).
- **Roblox knowledge** from `TabooHarmony/roblox-brain` (MIT, pinned in `skills-lock.json`; licence in `.claude/skills/ROBLOX_BRAIN_LICENSE`):
  - Core: roblox-collaboration-mode, roblox-architecture, roblox-data, roblox-server-data, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-networking, roblox-performance, roblox-security
  - Gameplay: roblox-animation-vfx, roblox-audio, roblox-building, roblox-camera, roblox-gui, roblox-input, roblox-lighting, roblox-localization, roblox-npc-ai, roblox-physics
  - Design: roblox-analytics, roblox-game-design, roblox-growth-design, roblox-monetization, roblox-player-psychology
  - Tools: roblox-cloud, roblox-publish-checklist, roblox-studio-mcp, roblox-tooling

### Using the skills (mandatory)
- The planner loads `roblox-collaboration-mode` first (with the precedence rules below), then each domain skill the change touches (`SKILL.md`; `references/full.md` only when needed), and copies the applicable checks into the plan's "Skill checks"; the other agents read those lines instead of the skills (the implementer of a tier S task without a plan reads the `SKILL.md` files itself). `CLAUDE.md` is in every agent's context already; agents do not read it again.

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
