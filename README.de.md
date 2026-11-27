# Roblox Game Template für Claude Code (Kurzanleitung)

Startgerüst für neue Roblox-Spiele, die Claude Code entwickelt: Regeln, Agents, Skills, Hooks, Blender-Art-Pipeline, Test-Runner und CI, aber kein Spielinhalt. Die ausführliche Anleitung steht in der [README.md](README.md) (Englisch).

## In 6 Schritten zum ersten Feature
1. **Repo anlegen:** auf GitHub „Use this template“ oder
   ```powershell
   gh repo create MeinSpiel --private --template Valentindghjg/roblox-game-template --clone
   ```
   danach im Ordner `rokit install`.
2. **Namen setzen:** `<GAME_NAME>` in `CLAUDE.md` und `"name"` in `default.project.json` und `release.project.json`.
3. **Studio verbinden:** `rojo serve default.project.json` starten, in Studio im Rojo-Plugin den `servePort` aus `default.project.json` als Port eintragen (jedes Spiel einen eigenen, das Template hat 34873) und auf **Connect** klicken, Claude Code im Ordner öffnen.
4. **Planen:** „Lass uns das Spiel planen: …“. Der Skill `game-plan` (Opus) füllt mit dir Spec, Game Design und Backlog.
5. **Arbeiten lassen:** „hasseln“ (oder `/hasseln`, „weiter“). Jede Aufgabe läuft durch planner → Implementer → playtester → reviewer, wird committet und gepusht.
6. **Was nur du lösen kannst**, steht oben im Backlog unter „Für den Owner am PC“, mit deinen Schritten. Erledigen, „weiter“ sagen, und es geht genau dort weiter.

## Gut zu wissen
- **Was nur du entscheidest:** Veröffentlichen und Robux-Produkte macht nur der Owner.
- **3D-Modelle:** Der modeler baut sie in Blender mit dem Kit `tools/art/kit/lowpoly_kit.py` und vergleicht seine Renderbilder mit deinen Referenzen in `docs/art/quality-reference/`. Hochladen ins Spiel geht erst mit einem Open-Cloud-API-Key (README, „Art pipeline setup“).
- **Token sparen:** Die Agents lesen nur die nötigen Abschnitte, Pläne haben eine Größengrenze, und das Fortschrittsprotokoll archiviert sich selbst.
- **UI-Pack (optional):** Das Essential UI Pack von Swarve Studios kann der Look deiner UI werden, muss aber nicht. Lizenz und Inhalt (alle Bild- und Sound-IDs) liegen in `assets/third_party/swarve-essential-ui/`. Die `.rbxl` legst du selbst dort ab; sie wird nicht committet. Details im englischen README, Abschnitt „Optional: Swarve UI pack“.
- **Tests:** `lune run tests/headless/run.luau`. Neue Module und Testfälle werden automatisch gefunden.
