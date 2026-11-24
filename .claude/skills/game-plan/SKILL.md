---
name: game-plan
description: Switches this chat to Opus 5.5 at high effort for planning in the game. Invoke it first, before answering, as soon as the user wants to plan, design or decide something - a feature, mechanic, architecture, spec, backlog, priorities, balancing, art direction, a workflow, or "how should this work". Not for doing the work; that is game-task.
model: claude-opus-5-5
effort: high
argument-hint: <what to plan>
---

# game-plan: planning on Opus 5.5, high effort

This turn should now run on Opus 5.5 at high effort. Planning topic: $ARGUMENTS

0. **Check the model first.** The system prompt names the model you are running on.
   - Opus 5.5: continue.
   - Sonnet or Haiku: the switch was not applied (`availableModels` or auto mode). **Stop immediately.** Plan nothing, write nothing and start no agent. Reply only with this German message: "Planen braucht Opus 5.5, aber der Modellwechsel wurde nicht angewendet. Bitte stell das Modell auf Opus (/model) und schick die Nachricht noch einmal."
   - Any other model: stay on it and continue. This skill raises the effort to high.
1. Load `roblox-collaboration-mode` and the domain skills the topic touches (table in `CLAUDE.md`).
2. Plan with the user in this chat. Read the relevant docs and code before you suggest anything. Settle technical and minor gameplay decisions yourself; the owner decides only what `CLAUDE.md` reserves for the owner.
3. Write the result where it belongs:
   - Owner decisions go to `docs/PRODUCT_SPEC.md` and get a dated entry in `docs/DECISION_LOG.md`.
   - New or changed tasks go to `docs/CLAUDE_BACKLOG.md`, with the goal, dependencies and verifiable acceptance criteria.
   - A complete task plan `docs/plans/<ID>.md` is written by the `planner` agent, or by `planner-high` for tier L. Start it with `subagent_type` only, and do not pass `model` or `effort`.
4. Commit documentation changes in small logical commits.
5. As soon as the user wants the planned work carried out, invoke the skill `game-task`. It switches the chat back to Sonnet and starts the right agent for each step.
