# Roblox Game Template

Startgerüst für neue Roblox-Spiele mit Claude Code: Regeln, Agents, Skills, Hooks, Blender-Art-Pipeline, Test-Runner und CI. Kein Spielinhalt.

## Neues Spiel starten
1. Auf GitHub **„Use this template“ → „Create a new repository“** (oder `gh repo create <name> --private --template Valentindghjg/roblox-game-template --clone`).
2. Im neuen Ordner:
   ```powershell
   rokit install
   ```
3. In `CLAUDE.md` die Zeile `Game: **<GAME_NAME>**` ausfüllen und in `default.project.json` / `release.project.json` den `"name"` setzen.
4. Claude Code im Ordner öffnen und sagen: **„Lass uns das Spiel planen“**. Der Skill `game-plan` füllt mit dir `docs/PRODUCT_SPEC.md` (Owner-Entscheidungen, Kernschleife, Meilensteine) und schreibt das erste Backlog.
5. Danach **„hasseln“** (oder `/hasseln`): Claude arbeitet das Backlog Aufgabe für Aufgabe ab, jede mit Plan, Umsetzung, Test, Review, Commit und Push.

## Was drin ist
| Bereich | Inhalt |
|---|---|
| `CLAUDE.md` | Regeln, Modell-Routing (Opus plant, Sonnet setzt um), Skill-Tabelle, Konfliktregeln |
| `.claude/agents/` | planner, implementer (S/M/L), modeler, playtester, reviewer |
| `.claude/skills/` | `game-plan`, `game-task`, `hasseln`, `blender-modeling` + 29 Roblox-Skills aus `TabooHarmony/roblox-brain` (MIT) |
| `.claude/hooks/` | Routing-Erinnerung pro Nachricht, Schreibschutz für den Hauptchat |
| `.mcp.json` | Roblox Studio MCP |
| `tools/art/` | Blender → FBX → Open Cloud → `.rbxm`-Pipeline (`art.luau`), Low-Poly-Kit `kit/lowpoly_kit.py` |
| `tests/` | Headless-Runner (Lune, findet Module und Tests automatisch), Studio-Runner, Art-Pipeline-Tests |
| `docs/` | Vorlagen: Spec, Design, Architektur, Testplan, Backlog („Für den Owner am PC“, „Studio-Test ausstehend“), Decision Log, Plan-Template, Qualitätsreferenz |
| `.github/workflows/quality.yml` | StyLua, Selene, luau-lsp, Headless-Tests, Rojo-Build, Art-Pipeline |

## Voraussetzungen auf dem PC
- Roblox Studio mit dem Rojo-Plugin und dem Studio-MCP (`.mcp.json`).
- [Rokit](https://github.com/rojo-rbx/rokit) für die gepinnten Tools.
- Blender 5.x für Modelle (`lune run tools/art/art.luau doctor` prüft das).
- Node.js für die Hooks.

## Art pipeline setup
Damit fertige Blender-Modelle ins Spiel hochgeladen werden, braucht es einen Open-Cloud-API-Key:
1. Auf create.roblox.com → Open Cloud → API Keys einen Key mit der Berechtigung **Assets: write** (und read) für deinen Account oder deine Gruppe anlegen.
2. Als Umgebungsvariablen setzen: `ROBLOX_OPEN_CLOUD_API_KEY` und `ART_CREATOR` (`user:<id>` oder `group:<id>`).
3. `lune run tools/art/art.luau doctor` muss „ok“ melden. Ohne Key baut und rendert der modeler trotzdem; nur der Upload wartet.

## Tägliche Befehle
```powershell
rojo serve default.project.json
```
```powershell
lune run tests/headless/run.luau
```
```powershell
lune run tools/art/art.luau render <artPath>
```
