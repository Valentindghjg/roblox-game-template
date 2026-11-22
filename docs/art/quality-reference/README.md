# Model quality reference (owner-supplied)

**Status: add the owner's images before the first MODEL task.** Put three liked and three disliked example images here as `liked-1..3.png` and `disliked-1..3.png` and describe them in the table. They stay local (`.gitignore`) because web images have unknown licences; the table below is binding when the PNGs are missing.

## The images (owner's default taste, carried over; adjust per game)
| File | Shows | Owner verdict and reason |
|---|---|---|
| liked-1 | Deciduous tree with a canopy of 10–15 rounded, softly faceted blobs and a smooth curved trunk with 2–3 branches. Fresh, natural greens, warm brown, soft light. | **Liked – the target for hero models.** Volume, soft facets, harmonious colours. |
| liked-2 | Very simple conifer: 3 stacked, flat-shaded tiers on a straight square trunk. | **Liked – the minimum level.** Simple, clean and readable. Enough for small or rarely seen things. |
| liked-3 | Faceted low-poly character with deliberate facets, a warm harmonious palette and expressive proportions. | **Liked – the level for models players see all the time.** |
| disliked-1 | Tree with many jagged, splintered leaf shards and painted bark strokes. Very saturated lime green. | **Disliked – too much.** Noisy, busy silhouette. |
| disliked-2 | Tree with 4 loose, unshaded blobs on thin stick branches, in pale flat colours. | **Disliked – too little.** Looks unfinished and cheap, no volume. |
| disliked-3 | Realistic tree with photo-like leaf cards. | **Disliked – wrong style.** Realism and alpha textures do not fit a stylised low-poly world. |

## Quality tiers
Every model gets one tier, set by the planner in the plan. If in doubt, take the higher tier.
- **Tier A – often or long in view** (the player's base, key buildings, vehicles, items for sale, landmarks). Target liked-3 and liked-1: a characteristic silhouette readable from far and near, with 2–3 levels of shape detail (main mass, secondary forms, a few accents). Budget 4000 triangles / 10 MeshParts.
- **Tier B – small, distant or rare** (background vegetation, rocks, fences, small decor, crates). Minimum liked-2: a simple, clean form with a clear silhouette and no gaps. Budget 1000 triangles / 4 MeshParts.

## Reference game (optional)
If the game follows a reference game, follow its style direction per model type (proportions, arrangement, colour mood) so players recognise the type, but never build the same model: own silhouette details, palette values and decoration, no logos, names, text or textures from it, and at least the main mass, the roof or the decoration must differ visibly. Notes and screenshots go under `docs/references/`.

## Review checklist
The modeler checks every new model against this list before integration and reports each item with evidence (the rendered previews, plus a Studio capture where possible).
1. **Style:** stylised low-poly with deliberate facets. No realistic textures, no alpha leaf cards, no painted detail (disliked-1, disliked-3).
2. **Detail level:** matches its tier; never as bare as disliked-2 and never as noisy as disliked-1.
3. **Silhouette:** closed and readable from a distance, no loose stick parts, no shard edges, no gaps.
4. **Colour:** the project palette (`src/shared/ArtPalette.lua`); saturated but natural, a light and a shade variant per material, harmonious across the scene.
5. **Proportions and scale:** the player is about 5 studs tall, doors about 4 × 7, counters 3.5–4 high.
6. **Reference look** (if there is a reference game): recognisable type, visibly our own model.
7. **Technical:** pivot and name correct, collision fits, runs on mobile, meets the definition of done in `docs/MODEL_INTEGRATION.md`.
