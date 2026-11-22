---
name: blender-modeling
description: How the modeler builds the game models in Blender 5.2 with the low-poly kit (tools/art/kit/lowpoly_kit.py) - building blocks, style rules, budget and the build-render-compare loop. Load it for every MODEL task and whenever a Blender build script is written or changed.
---

# blender-modeling: Blender models with the low-poly kit

Pipeline contract: `docs/MODEL_INTEGRATION.md`, "Asset pipeline".

**Save tokens:** do not open `tools/art/kit/lowpoly_kit.py`; the table below is its interface. Copy the pattern from `tools/art/kit/examples/market_stall.py` (30 lines). Read only the previews you need.

## Workflow
1. Write `assets/art/source/<artPath>/build.py` (import the kit, define `build()`, end with `K.run(build, tier="A"|"B")`) and `asset.json` (schemaVersion 1, artPath, displayName, tier, version, requiredAttachments, upload {}).
2. Build: `blender -b --factory-startup --python assets/art/source/<artPath>/build.py -- --out assets/art/source/<artPath>/model.blend` (Blender path: `lune run tools/art/art.luau doctor`). Expect `KIT_OK triangles=… meshparts=…`; `KIT_OVER_BUDGET` exits 4.
3. `lune run tools/art/art.luau export <artPath>` (contract check), then `render <artPath>`.
4. Look at `assets/art/_build/<artPath>/preview_34.png`; open `preview_front.png` only to check the front or symmetry. Compare with `docs/art/quality-reference/` (README checklist; look at the liked/disliked images once per task, not every round).
5. Fix and repeat steps 2-4, at most three rounds. Upload and normalize only with the Open Cloud key (README, "Art pipeline setup"); otherwise report the upload as BLOCKED (missing Open Cloud key).

## Kit interface (`import lowpoly_kit as K`)
Units: studs; Z up; front = -Y; origin = ground pivot. `part` and `key` are CamelCase; `key` is an `ArtPalette` key.
| Call | Makes |
|---|---|
| `K.box(part, key, size, loc, rot=(0,0,0), bevel=0)` | box centred on loc; rot in degrees |
| `K.cylinder(part, key, radius, depth, loc, rot, verts=8, bevel=0)` | upright cylinder |
| `K.cone(part, key, r_bottom, r_top, depth, loc, rot, verts=8)` | cone or frustum |
| `K.ball(part, key, radius, loc, detail=1)` | low-poly ball (80 tris; detail 0 = 20) |
| `K.prism(part, key, width, depth, height, loc, rot)` | gable-shaped prism, ridge along Y |
| `K.planks(part, key, count, size, start, step, bevel=0.03, jitter=0)` | row of boards |
| `K.post(part, key, height, foot, width=0.5)` | square post standing on foot |
| `K.gable_roof(part, key, width, depth, height, base_z, overhang=0.6, thickness=0.3, snow=True, center=(0,0))` | two slabs, ridge along Y, snow layer |
| `K.snow_cap(size, bottom_centre)` | soft snow slab on a surface |
| `K.fir(height, base_radius, loc, tiers=4, snow=True, verts=7)` | trunk plus stacked cones with snow (~60 tris per tier) |
| `K.string_lights(start, end, count, sag=0.6)` | LightWarm bulbs on a MetalDark wire |
| `K.wheel(radius, width, centre, axis="X")` | wheel with hubs |
| `K.awning(width, depth, back_edge_centre, stripes=4)` | striped awning sloping to the front |
| `K.collider(name, size, loc)` | `COL_<name>`, never rotated |
| `K.attachment(name, loc)` | `ATT_<name>`; trees need `TreeBase` at the ground point |
| `K.seed(n)` | fixed randomness, so rebuilds match |
| `K.run(build, tier, merge="key")` | builds, joins one MeshPart per colour, checks budget, saves |

Need a shape the kit lacks? Write it inside your build script with `bpy`/`bmesh`; if two tasks need it, propose adding it to the kit in your report.

## Style rules
- Low-poly with flat shading: 6-10 sides on round shapes, chunky readable silhouettes, slightly exaggerated proportions (thick posts, deep roofs, big snow).
- Rounded edges: bevel 0.03-0.06 on wood, 0.08-0.12 on snow. No perfectly sharp boxes on hero models.
- Depth through colour pairs: main key plus its `…Shade` key (WoodWarm/WoodWarmShade, NeedleGreen/NeedleGreenShade). No textures, no logos, no text.
- Snow on every upward surface outdoors (roofs, tier tops, ledges), slightly overhanging edges.
- Hand-built feel: `jitter` on planks, `K.seed` for repeatable variation; avoid perfect repetition.
- Budget: tier A 4000 triangles / 10 MeshParts, tier B 1000 / 4. Merge by colour (default); use few colours on tier B.
- Scale: a player is about 5 studs tall; counters about 3.5 studs, doorways at least 7 studs.

## Report additions
Triangles and MeshParts from the `KIT_OK` line, render rounds used, and which checklist items each round fixed.
