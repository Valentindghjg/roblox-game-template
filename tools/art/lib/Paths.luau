--!strict
-- Directory layout of the art pipeline: all paths derive from --root and an art path.
local ArtLibrary = require("../../../src/shared/ArtLibrary")

local Paths = {}

Paths.DEFAULT_ROOT = "assets/art"

function Paths.isValid(artPath: string): boolean
	return ArtLibrary.isValidPath(artPath)
end

function Paths.leaf(artPath: string): string
	return string.match(artPath, "([^/]+)$") or artPath
end

function Paths.sourceDir(root: string, artPath: string): string
	return root .. "/source/" .. artPath
end

function Paths.blendFile(root: string, artPath: string): string
	return Paths.sourceDir(root, artPath) .. "/model.blend"
end

function Paths.specFile(root: string, artPath: string): string
	return Paths.sourceDir(root, artPath) .. "/asset.json"
end

function Paths.buildDir(root: string, artPath: string): string
	return root .. "/_build/" .. artPath
end

function Paths.rbxmFile(root: string, artPath: string): string
	return root .. "/rbxm/" .. artPath .. ".rbxm"
end

-- The directory part of a file path, for creating it before a write.
function Paths.parentDir(file: string): string
	return string.match(file, "^(.*)/[^/]+$") or "."
end

return Paths
