---
name: hasseln
description: Works through the whole the game backlog in one go - task after task through the game-task pipeline, without waiting for replies, until everything in scope is done, the owner says stop, or nothing workable is left. Invoke it when the user says "durcharbeiten", "arbeite durch", "mach weiter", "weiter", "hustle", "hasseln", "alles abarbeiten" or types /hasseln. On any blocker it secures the work, records a machine-readable "Für den Owner am PC" entry and has the planner refresh the backlog.
model: claude-sonnet-5-5
effort: high
argument-hint: "[scope: empty = whole backlog | milestone like P1 | task IDs | a number of tasks]"
---

# hasseln: work through the backlog

This chat orchestrates on Sonnet 5.5; every step runs in the agent named by `game-task`, on that agent's own model.
First check the model the system prompt names. If it is not Sonnet 5.5, the switch was not applied: stay on the current model and continue (this skill sets the effort to high).

Scope: $ARGUMENTS

- Empty: every open task in `docs/CLAUDE_BACKLOG.md`, then the gap check (step 6).
- A milestone (`P1` … `P5`), a list of task IDs, or a number N (the next N ready tasks): only those. No gap check outside the scope.

## Rules for the whole run
- The main chat writes nothing itself (CLAUDE.md): the `planner` writes the backlog and plans, the `reviewer` commits. Start agents with `subagent_type`, `description` and `prompt` only; never pass `model` or `effort`.
- One session, one task at a time. Do not start other sessions or worktrees, and do not run tasks in parallel.
- Every commit is pushed right away by whoever commits. Never force-push, merge branches on the remote, publish, or create or enable paid products. A failed push is a blocker (step 5, kind `zugriff`).
- Never commit `.mcp.json`, secrets or `build.rbxlx`, and never touch uncommitted changes the owner made. If `git status` shows foreign changes in files a task needs, treat that as a blocker (step 5).
- Do not stop between tasks, at milestone gates or after reports. Do not call `wrap_up` and do not end the turn until a stop condition in step 7 is met.
- Keep the chat lean: pass file paths and short reports between agents, not file contents. After each task, write at most two lines to the user (task, verdict, commit SHA). The task list (`update_plan`) shows the run: one item per task, plus "Backlog aktualisieren" and "Abschlussbericht".

## 1. Start
1. `git status` and `git log --oneline -5`. Note foreign uncommitted changes and leave them alone.
2. Read the section **"Für den Owner am PC"** at the top of `docs/CLAUDE_BACKLOG.md`. For each entry, check whether the owner has resolved it (the entry's `Prüfen` field says how, e.g. the Studio MCP answers `list_roblox_studios`, the Rojo plugin is connected, a decision is in DECISION_LOG). Collect what is resolved and what is still open.
3. If any entry is resolved, or the backlog has no launch order yet (section "Launch order"), start `planner` once: "Refresh `docs/CLAUDE_BACKLOG.md` for a hasseln: mark these PC entries resolved and move them to `Erledigt` with the date: <list>; put their follow-up tasks first in the launch order; [if missing] write the launch order section from the milestones and the release target in `docs/PRODUCT_SPEC.md`. Change only docs." Then start `reviewer` with "Docs-only change by the planner for hasseln: check it and commit it." These two steps are the only planning outside a task.

## 2. Pick the next task
**First: is SLIM due?** Check the due rules in the section "Recurring task: SLIM" of `docs/CLAUDE_BACKLOG.md`. If it is due, the next task is `SLIM` (step 3), before anything else. It counts as a normal task.

Take the first task that meets all of these, in this order of sources: the "Launch order" section, then the milestone sections in dependency order, then the follow-up sections.
- Not ticked (`- [ ]`) and in scope.
- Every task in its "Depends on" is done.
- It is not listed in an open "Für den Owner am PC" entry under `Blockiert`, and it does not need the owner (an owner decision, publication, paid products, Robux or the owner's account). Skip such tasks silently and take the next one.
- It has not been blocked in this run already.
If no task qualifies, go to step 6.

## 3. Run the task
Invoke the skill `game-task` with the task ID and follow it step by step (planner, implementer tier or modeler, playtester, reviewer). Its own rules apply, with these additions:
- A Studio playtest that cannot run (Studio closed, MCP or Rojo plugin not connected): try once to reconnect (`list_roblox_studios`, then the playtester again). If it still fails, the playtest counts as BLOCKED; the reviewer still reviews and commits, and the missing Studio checks become a blocker entry (step 5, kind `studio`). The task itself is not counted as blocked.
- After the reviewer reports COMMITTED, check with `git log -1` that the commit exists and that the backlog item is ticked or has a dated status line. If the reviewer did not tick it, have it do that in the same commit series.

## 4. Count failures
- The same task returns "RE-PLAN NEEDED" twice, or the implementer asks the same question twice, or an agent fails twice the same way: the task is **blocked**. Go to step 5, then step 2.
- Three tasks blocked in a row (without a COMMITTED in between): stop the run (step 7, reason "drei Blocker in Folge").
- A milestone's last task is done: write one short milestone line to the user and go on.

## 5. Secure and record a blocker
A blocker is anything the run cannot fix itself after one obvious attempt: a missing tool, no access to Studio, Rojo, the network or an API, a check that fails for outside reasons, foreign changes in needed files, or a question only the owner can answer.
1. **Secure the work.** Start `reviewer`: "Task <ID> stopped because of <reason>. Run the checks. If they and the review pass, commit to `main` as usual and say what is still missing. If not, commit the current state to a new branch `wip/<ID>` (create it from the current `HEAD`, commit, push it, switch back to `main`), so `main` stays clean. Report the branch and SHA." Nothing unfinished may stay uncommitted, and unfinished code never lands on `main`.
2. **Record it.** Start `planner`: "Add a blocker to `docs/CLAUDE_BACKLOG.md` for hasseln: <ID>, <reason>, <what was tried>, <WIP branch or commit>. Write it in the section 'Für den Owner am PC' in the exact format of that section, create the follow-up task with goal, dependencies and verifiable acceptance criteria, and place it in the launch order right after the owner fixes it. Change only docs." Then `reviewer`: "Docs-only change by the planner: check and commit."
3. Continue with step 2. Tasks that need the same missing thing are skipped from now on.

## 6. Nothing ready
- Scope empty (whole backlog): start `planner`: "Gap check for hasseln: compare the implementation and the verified results with `docs/PRODUCT_SPEC.md`, the milestone gates in `docs/CLAUDE_BACKLOG.md` and `docs/TEST_PLAN.md`. Add follow-up tasks only for gaps you can trace to one of these three documents (name the section), with goal, dependencies and verifiable acceptance criteria. Report NONE if there is no such gap. Change only docs." If tasks were added: `reviewer` commits them, then step 2. If NONE: step 7.
- Narrow scope: step 7.

## 7. End the run
The run ends only when: everything in scope is done and verified; the owner says stop; three blockers in a row; or every remaining in-scope task is blocked or waits for the owner.
0. **Run the Studio queue.** If "Studio-Test ausstehend" in `docs/CLAUDE_BACKLOG.md` lists tasks and Studio is available, start `playtester` with all their plan paths (a batch run, skill `game-task` step 3), handle failures as that step says, and have the `reviewer` record and commit the result. Nothing deferred may stay untested when Studio could run it.
1. **Refresh the backlog** unless everything is done. Start `planner`: "Refresh the whole `docs/CLAUDE_BACKLOG.md` after a hasseln, assuming the owner will resolve every open 'Für den Owner am PC' entry before the next run: tick what is done, update status lines, fix dependencies, put the follow-up tasks of the PC entries first in the launch order, and make every PC entry complete in the section's format. Change only docs." Then `reviewer` commits it.
2. **Report** in German, in the "Reporting format for planner review" from CLAUDE.md, with this at the very top:
   - **Für dich am PC:** each open entry as ID, what to do in numbered steps, and what it unblocks. Say "nichts" if there is none.
   - Then: tasks done (ID, commit SHA, agents used), tasks blocked (ID, reason, WIP branch), tasks skipped because they need the owner, and why the run ended.
   - Last: "Danach `/hasseln` (oder „weiter“): er prüft zuerst die PC-Einträge und macht dort weiter."
3. Only now call `wrap_up`, then the closing message.

## Format of "Für den Owner am PC"
The section stays at the top of `docs/CLAUDE_BACKLOG.md`, directly under the title. The planner writes every entry in exactly this shape, so a person can follow it and the next run can parse it:

```
### PC-<n> <short title>
- Status: offen | erledigt <YYYY-MM-DD>
- Art: studio | rojo | zugriff | tool | entscheidung | fremde-aenderung | sonstiges
- Problem: <what blocked the run, one sentence>
- Deine Schritte:
  1. <concrete step on the PC>
  2. <...>
- Prüfen: <how the next run checks that it is resolved>
- Blockiert: <task IDs>
- Danach: <follow-up task ID, which runs first in the next hasseln>
- WIP-Branch: <wip/<ID> @ <sha> | none>
- Seit: <YYYY-MM-DD>, hasseln
```

Resolved entries move to a sub-section `#### Erledigt` at the end of that section.
