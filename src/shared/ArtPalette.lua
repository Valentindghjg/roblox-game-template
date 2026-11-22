--!strict
-- Original palette for Blender-made art (art pipeline; PROVISIONAL). Blender objects are named
-- <PartName>__<PaletteKey>; the pipeline paints MeshParts from this table, so models need
-- no textures. Pure data: usable from Lune tools and the game. Add keys freely; never
-- change an existing value without a DECISION_LOG entry.
export type PaletteEntry = { rgb: { number }, material: string }

local ArtPalette: { [string]: PaletteEntry } = {
	NeedleGreen = { rgb = { 46, 107, 69 }, material = "SmoothPlastic" },
	NeedleGreenShade = { rgb = { 28, 74, 50 }, material = "SmoothPlastic" },
	NeedleFrost = { rgb = { 196, 222, 214 }, material = "SmoothPlastic" },
	BarkBrown = { rgb = { 110, 72, 45 }, material = "SmoothPlastic" },
	BarkBrownShade = { rgb = { 78, 50, 32 }, material = "SmoothPlastic" },
	WoodWarm = { rgb = { 168, 112, 66 }, material = "SmoothPlastic" },
	WoodWarmShade = { rgb = { 122, 78, 44 }, material = "SmoothPlastic" },
	RoofRed = { rgb = { 170, 46, 46 }, material = "SmoothPlastic" },
	RoofRedShade = { rgb = { 122, 32, 36 }, material = "SmoothPlastic" },
	SnowWhite = { rgb = { 240, 244, 248 }, material = "SmoothPlastic" },
	SnowShade = { rgb = { 206, 218, 230 }, material = "SmoothPlastic" },
	StoneGray = { rgb = { 132, 138, 146 }, material = "SmoothPlastic" },
	StoneGrayShade = { rgb = { 96, 102, 112 }, material = "SmoothPlastic" },
	MetalDark = { rgb = { 52, 58, 64 }, material = "SmoothPlastic" },
	FabricCream = { rgb = { 232, 220, 196 }, material = "SmoothPlastic" },
	GoldAccent = { rgb = { 214, 170, 72 }, material = "SmoothPlastic" },
	LightWarm = { rgb = { 255, 214, 140 }, material = "Neon" },
}

return ArtPalette
