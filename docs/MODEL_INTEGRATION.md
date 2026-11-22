# Model integration

Original models only (CLAUDE.md). Larger models come from Blender through the art pipeline below; small items and blockout stay Parts.

## Roblox Studio hierarchy
Put models into `ReplicatedStorage/ArtAssets` during development, or server-only originals in `ServerStorage/ArtAssets` where appropriate:
- `Trees/<Species>/<Size>` (Small, Medium, Large)
- `Buildings/<TierId>`
- `Props/<AssetId>`
- `Vehicles/<AssetId>`
- `NPCs/<CharacterId>`
- `Environment/<AssetId>`

## Model conventions
- All models have a valid PrimaryPart or pivot and stable orientation (forward = -Z).
- Trees have a `TreeBase` attachment or a stable ground pivot.
- Vehicles have `DriverSeat` or `DriveRoot` and `CargoAnchor` as relevant.
- NPCs use a Roblox-compatible Humanoid and HumanoidRootPart when AI animation/navigation is needed.
- Names are case-sensitive; use exact IDs from shared config, not visible display names.
- Anchoring/collision is controlled by placement service; avoid scripts inside imported models.
- Include bounding-box dimensions and note any required animation IDs.
- Upload models in small batches; integration team validates scale, pivot, attachments and collisions.


Definition of done per model: original geometry, named and pivoted correctly, fitting collision and scale, performant on mobile, preview-reviewed against `docs/art/quality-reference/`, Studio-tested, listed in the asset inventory.

## Asset pipeline
Larger models are Blender MeshParts; small items stay Parts. The `.blend` in `assets/art/source/<artPath>/` is the source; `tools/art/art.luau` exports it to FBX, uploads it through Open Cloud (or the Studio import fallback) and normalizes the result into `assets/art/rbxm/<artPath>.rbxm`, which Rojo maps into `ReplicatedStorage.ArtAssets`. Full rules and commands: `assets/art/README.md`.
- Pivot: Blender origin = ground pivot, front = Blender -Y, 1 unit = 1 stud; the normalized model's `PrimaryPart` is `ArtRoot` at `CFrame.identity` (size 0.05, transparent). `WorldPivot` is not used.
- Colour and material come from `src/shared/ArtPalette.lua` through the object name `<PartName>__<PaletteKey>`; no textures. `COL_<Name>` boxes become `Collider_<Name>`; `ATT_<Name>` empties become Attachments under `ArtRoot` (`Trees/*` always has `TreeBase`).
- Attributes on every normalized model: `ArtAssetId`, `ArtPath`, `ArtSource = "blender"`, `ArtVersion`, `ArtTier`. Budgets: tier A 4000 triangles / 10 MeshParts, tier B 1000 / 4.
- `ArtLibrary.find/prepareClone` (`src/shared/ArtLibrary.lua`) look art up and clone it; a missing or broken path logs `[ART] <MissingArtAsset|InvalidArtAsset|InvalidArtPath> <path>` once per path and the primitive fallback stays.
- Checks: `tests/tools/art_pipeline.luau`, `art.luau verify <place>` (CI), playtest step `ART_ASSETS`.
- Building blocks and style rules: skill `blender-modeling`, kit `tools/art/kit/lowpoly_kit.py`, example `tools/art/kit/examples/market_stall.py`.
