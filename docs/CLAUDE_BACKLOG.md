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

## Recurring task: SLIM repo hygiene
The same task runs again and again; each run is one `game-task` with the ID `SLIM` and its date. **Tier S**: no planner, `implementer` (Sonnet medium) works from this entry, `reviewer` commits with `(SLIM)` in every commit subject (the due check below finds the last run through it).

**When it is due** (skill `hasseln`, step 2, checks this before it picks a task; run it by hand with `cm2-task SLIM`):
- no commit with `SLIM` in its subject yet, or
- 8 or more `feat`/`fix` commits since the last one (`git log --oneline <last SLIM sha>..HEAD | grep -cE "^[0-9a-f]+ (feat|fix)"`), or
- `docs/CLAUDE_BACKLOG.md` or `docs/DECISION_LOG.md` is over 80 KB, or `CLAUDE.md` over 16 KB, or
- the next task is the QA task or the release candidate.

**Goal:** find what nobody uses and what is too big, and shrink it, so agents read less per task. No behaviour change.

**Method:** use tools, do not read every file in full: `git ls-files` with sizes (`wc -c`), `grep -rn` for references, `selene` for unused locals.

**Find (report every hit with its evidence):**
1. Dead files anywhere in the repo: scripts, tools, docs, assets, configs and skills that nothing references (no `require`, no path in `default.project.json`, code, docs or tools).
2. Dead code: modules never required, exported functions never called, config keys never read, `Localization` keys never used, actions in `Protocol` never sent or never handled.
3. Dead text: doc sections about removed or superseded things, duplicates of other docs, finished status notes.
4. Too big: text files over these budgets: `CLAUDE.md` 12 KB (it is loaded on every message), `docs/CLAUDE_BACKLOG.md` 60 KB, `docs/DECISION_LOG.md` 60 KB, `docs/PROGRESS.md` 20 KB, any other doc 30 KB, any Luau file 800 lines.

**Fix in this run (tier S allows it):**
- Docs: shorten wording without changing meaning; move finished material into `docs/archive/`:
  - backlog: ticked task lines with their status notes, resolved PC entries and done "current run" blocks go to `docs/archive/BACKLOG_DONE_<first date>_to_<last date>.md`, leaving one line per task ID (`- [x] <ID> title, done <date>, see archive`);
  - decision log: entries older than 14 days go to `docs/archive/DECISION_LOG_<first date>_to_<last date>.md` unchanged; they stay binding;
  - plans of ticked tasks go to `docs/archive/plans/`; update links that pointed to them.
- Delete dead files outside `src/` and dead code in `src/client`, `tests` and `tools`, each only with grep evidence that nothing references it.
- Never delete an owner decision, test evidence, a licence or provenance record, or anything in `.claude/settings*.json` and hooks; archive instead.

**Do not fix here, file it instead:** dead code in `src/server` or `src/shared`, anything near saves, money, inventory, purchases or remotes, and splitting Luau files over budget. Each becomes a follow-up task right after the current launch-order task (dead code: tier by the template rules; splits: after the release candidate, not before release).

**Accept:**
- (a) A PROGRESS entry with a before/after table: size of the 10 largest text files, line counts of `src`, `tests` and `docs`, and the total size of what agents read every task (`CLAUDE.md` + the backlog + the last 60 KB of the decision log).
- (b) Every removal is listed with its grep evidence; every archived block is findable by its task ID (`grep -rn <ID> docs/` hits it).
- (c) `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` and `rojo build` pass; the headless count is unchanged unless a test of removed dead code went with it, and then each removed test is named.
- (d) Follow-up tasks are in the backlog with goal, tier and acceptance criteria, or the entry says "none".
- (e) Studio: not needed when only docs and files outside `src` changed; otherwise the Studio queue rules of `game-task` step 3 apply.

Runs: none yet.

## Launch order
_Written by the planner in the first planning session._

## P0 — Foundation
- [ ] **G-01 Project setup check** · S · Depends: none. Accept: `rokit install` works, CI `Quality` passes on main, `rojo serve` connects in Studio, `lune run tools/art/art.luau doctor` finds Blender.

## P1 — Playable core
_Tasks from the first planning session._

## Milestone gates
- P0: tools, unit tests, safe persistence and network foundation.
- P1: the core loop playable in Studio, with save and rejoin.
