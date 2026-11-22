--!nonstrict
-- Checks that integrated art really sits in a built place at the expected path.
-- Reads only ClassName, Name, MeshContent, Size, CFrame, PrimaryPart and attributes:
-- Lune 0.11 cannot read TextureID, WorldPivot or CollisionFidelity after a deserialize.
local AssetSpec = require("./AssetSpec")
local Paths = require("./Paths")

local Verify = {}

export type Failure = { artPath: string, code: string, detail: string? }

local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }
local PIVOT_EPSILON = 1e-4
local IDENTITY = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function isIdentity(cframe: any): boolean
	local components = { cframe:GetComponents() }
	for index, expected in ipairs(IDENTITY) do
		if math.abs(components[index] - expected) > PIVOT_EPSILON then
			return false
		end
	end
	return true
end

local function find(root: any, artPath: string): any
	local current = root
	for segment in string.gmatch(artPath .. "/", "([^/]*)/") do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

-- entries: { { artPath, spec, hasRbxm } }. Only entries with an .rbxm are checked.
function Verify.verifyPlace(place: any, entries: { any }): { Failure }
	local failures: { Failure } = {}
	local artAssets = place:GetService("ReplicatedStorage"):FindFirstChild("ArtAssets")
	for _, entry in ipairs(entries) do
		if entry.hasRbxm then
			local artPath, spec = entry.artPath, entry.spec
			local function fail(code: string, detail: string?)
				table.insert(failures, { artPath = artPath, code = code, detail = detail })
			end
			local model = find(artAssets, artPath)
			if model == nil or model.ClassName ~= "Model" then
				fail("MissingArtAsset")
			else
				local primary = model.PrimaryPart
				if primary == nil or primary.Name ~= "ArtRoot" or not isIdentity(primary.CFrame) then
					fail("ART_BAD_PIVOT")
				end
				if model:GetAttribute("ArtVersion") ~= spec.version then
					fail(
						"ART_VERSION_MISMATCH",
						string.format("%s vs %s", tostring(model:GetAttribute("ArtVersion")), tostring(spec.version))
					)
				end
				local expected = {
					ArtAssetId = Paths.leaf(artPath),
					ArtPath = artPath,
					ArtSource = "blender",
					ArtTier = spec.tier,
				}
				for name, value in pairs(expected) do
					if model:GetAttribute(name) ~= value then
						fail("ART_BAD_ATTRIBUTE", name)
					end
				end
				local meshCount, badMesh, scriptName = 0, nil, nil
				for _, descendant in ipairs(model:GetDescendants()) do
					if SCRIPT_CLASSES[descendant.ClassName] then
						scriptName = scriptName or descendant.Name
					elseif descendant.ClassName == "MeshPart" then
						meshCount += 1
						local uri = descendant.MeshContent.Uri
						if type(uri) ~= "string" or string.match(uri, "^rbxassetid://%d+$") == nil then
							badMesh = badMesh or descendant.Name
						end
					end
				end
				if meshCount == 0 then
					fail("ART_BAD_MESH", "no MeshPart")
				elseif badMesh ~= nil then
					fail("ART_BAD_MESH", badMesh)
				end
				if scriptName ~= nil then
					fail("ART_SCRIPT_FOUND", scriptName)
				end
				for _, name in ipairs(AssetSpec.requiredAttachments(spec)) do
					local attachment = primary and primary:FindFirstChild(name)
					if attachment == nil or attachment.ClassName ~= "Attachment" then
						fail("ART_MISSING_ATTACHMENT", name)
					end
				end
			end
		end
	end
	return failures
end

-- Both lists hold art paths. An .rbxm without asset.json is an orphan; an asset.json without
-- an .rbxm is merely pending.
function Verify.verifyFiles(rbxmPaths: { string }, specPaths: { string }): ({ Failure }, { string })
	local hasSpec: { [string]: boolean } = {}
	for _, artPath in ipairs(specPaths) do
		hasSpec[artPath] = true
	end
	local hasRbxm: { [string]: boolean } = {}
	local failures: { Failure } = {}
	for _, artPath in ipairs(rbxmPaths) do
		hasRbxm[artPath] = true
		if not hasSpec[artPath] then
			table.insert(failures, { artPath = artPath, code = "ART_ORPHAN_RBXM", detail = nil })
		end
	end
	local pending: { string } = {}
	for _, artPath in ipairs(specPaths) do
		if not hasRbxm[artPath] then
			table.insert(pending, artPath)
		end
	end
	return failures, pending
end

return Verify
