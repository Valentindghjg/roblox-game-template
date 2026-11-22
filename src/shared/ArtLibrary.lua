--!strict
-- Lookup and cloning of art models under ReplicatedStorage.ArtAssets.
-- An art path is 1-4 segments of PascalCase names, for example "Buildings/MarketStarter".
local ArtLibrary = {}

local MAX_SEGMENTS = 4

function ArtLibrary.isValidPath(path: string): boolean
	if type(path) ~= "string" or path == "" then
		return false
	end
	local count = 0
	for segment in string.gmatch(path .. "/", "([^/]*)/") do
		count += 1
		if count > MAX_SEGMENTS or string.match(segment, "^%u%w*$") == nil then
			return false
		end
	end
	return count >= 1
end

-- Returns the template Model, or nil and one of InvalidArtPath, MissingArtAsset,
-- InvalidArtAsset. Legacy CC0 models may lack a PrimaryPart; Blender art needs one.
function ArtLibrary.find(root: Instance?, artPath: string): (Model?, string?)
	if not ArtLibrary.isValidPath(artPath) then
		return nil, "InvalidArtPath"
	end
	local current: Instance? = root
	if current == nil then
		return nil, "MissingArtAsset"
	end
	for segment in string.gmatch(artPath .. "/", "([^/]*)/") do
		current = (current :: Instance):FindFirstChild(segment)
		if current == nil then
			return nil, "MissingArtAsset"
		end
	end
	local leaf = current :: Instance
	if not leaf:IsA("Model") then
		return nil, "InvalidArtAsset"
	end
	local model = leaf :: Model
	if model:GetAttribute("ArtSource") == "blender" and model.PrimaryPart == nil then
		return nil, "InvalidArtAsset"
	end
	return model, nil
end

-- Clones a template for placement. Blender art keeps its authored collision; legacy
-- models collide everywhere, as before.
function ArtLibrary.prepareClone(template: Model): Model
	local model = template:Clone()
	local keepCollision = template:GetAttribute("ArtSource") == "blender"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			if not keepCollision then
				descendant.CanCollide = true
			end
		end
	end
	model:SetAttribute("ArtAssetId", template.Name)
	return model
end

return ArtLibrary
