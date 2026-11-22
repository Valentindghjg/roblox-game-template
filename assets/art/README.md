# Art pipeline: Blender -> MeshParts

The `.blend` file is the art source. `rbxm/<artPath>.rbxm` is the normalized build input that Rojo maps into
`ReplicatedStorage.ArtAssets`. Everything under `_build/` is generated and gitignored (FBX, report, raw.rbxm, previews).
`artPath` is the path under ArtAssets, for example `Trees/DouglasFir/Medium` or `Buildings/MarketStarter`
(1-4 segments, each `^%u%w*$`). The leaf is the model name and the `ArtAssetId`.

Layout: `source/<artPath>/model.blend` + `asset.json`, `rbxm/<artPath>.rbxm`, `_build/<artPath>/`.

## Blender rules
- Origin = ground pivot: the footprint centre at ground level. The front faces Blender -Y. 1 Blender unit = 1 stud.
- Mesh objects are named `<PartName>__<PaletteKey>` (palette: `src/shared/ArtPalette.lua`). No textures; colour and
  material come from the palette. Flat shading is forced on export.
- Collision: `COL_<Name>` meshes are unrotated boxes and become invisible `Collider_<Name>` parts. With any collider the
  MeshParts do not collide; without one they do (collision fidelity Box).
- Attachments: empties named `ATT_<Name>` (`ATT_TreeBase`, `ATT_Entrance`, ...). `Trees/*` always needs `TreeBase`;
  `asset.json` lists the others in `requiredAttachments`.
- Budgets (PROVISIONAL): tier A at most 4000 triangles and 10 MeshParts, tier B at most 1000 and 4. `asset.json` may
  lower them, never raise them. Save the `.blend` with "Compress".
- `asset.json` (schemaVersion 1): `artPath`, `displayName`, `tier`, `version`, `requiredAttachments`, `upload`.

## Commands (repository root, Blender 5.2.2 at the default path or `GAME_BLENDER`)
```
lune run tools/art/art.luau doctor                      Blender, API key, creator (exit 0, 2 = key missing, 1 = no Blender)
lune run tools/art/art.luau render <artPath>            previews in _build/<artPath>/ (no upload needed)
lune run tools/art/art.luau export <artPath>            model.fbx + report.json
lune run tools/art/art.luau upload <artPath> [--force]  Open Cloud upload, download raw.rbxm (needs the key)
lune run tools/art/art.luau normalize <artPath> [--raw <file>]
lune run tools/art/art.luau build <artPath>             export, upload, normalize
lune run tools/art/art.luau verify <placeFile>          integrated art against a built place
lune run tools/art/art.luau probe                       the generated pipeline probe, end to end
```
Every command takes `--root <dir>` (default `assets/art`). Upload needs `ROBLOX_OPEN_CLOUD_API_KEY` and
`ART_CREATOR` (`user:<id>` or `group:<id>`) in the environment; without them `upload` exits 2 with `ART_NO_API_KEY`.
Never paste or commit the key.

## Studio import fallback (no API key)
1. `export <artPath>`.
2. Studio: Home -> Import 3D -> `_build/<artPath>/model.fbx` -> keep the defaults -> Import.
3. Right-click the imported model -> Save to File -> `_build/<artPath>/raw.rbxm`.
4. `normalize <artPath>`.
Use this only while the API key is missing and a model needs a mesh in Studio.

## Rules
- An invisible mesh in Studio usually means the uploaded asset is private and the experience has no grant: check the
  Creator Dashboard asset permissions.
- Asset IDs never derive from file names. Missing art falls back to primitives and logs
  `[ART] MissingArtAsset <path>` once per path.
