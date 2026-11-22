--!strict
-- asset.json (schemaVersion 1): validation, tier budgets and a stable serializer.
local serde = require("@lune/serde")
local ArtLibrary = require("../../../src/shared/ArtLibrary")
local Config = require("./Config")

export type Upload = { modelAssetId: string?, sourceSha256: string?, uploadedAt: string? }
export type Spec = {
	schemaVersion: number,
	artPath: string,
	displayName: string,
	tier: string,
	version: number,
	maxTriangles: number?,
	maxMeshParts: number?,
	requiredAttachments: { string },
	upload: Upload,
}

local AssetSpec = {}

local function isWhole(value: any, minimum: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= minimum
end

local function isOptionalString(value: any): boolean
	return value == nil or type(value) == "string"
end

-- Returns the spec, or nil and "ART_BAD_SPEC <field>".
function AssetSpec.validate(data: any, expectedArtPath: string?): (Spec?, string?)
	local function bad(field: string): (Spec?, string?)
		return nil, "ART_BAD_SPEC " .. field
	end
	if type(data) ~= "table" then
		return bad("document")
	end
	if data.schemaVersion ~= 1 then
		return bad("schemaVersion")
	end
	if type(data.artPath) ~= "string" or not ArtLibrary.isValidPath(data.artPath) then
		return bad("artPath")
	end
	if expectedArtPath ~= nil and data.artPath ~= expectedArtPath then
		return bad("artPath")
	end
	if type(data.displayName) ~= "string" or data.displayName == "" then
		return bad("displayName")
	end
	local budget = Config.BUDGET[data.tier]
	if type(data.tier) ~= "string" or budget == nil then
		return bad("tier")
	end
	if not isWhole(data.version, 1) then
		return bad("version")
	end
	if data.maxTriangles ~= nil and (not isWhole(data.maxTriangles, 1) or data.maxTriangles > budget[1]) then
		return bad("maxTriangles")
	end
	if data.maxMeshParts ~= nil and (not isWhole(data.maxMeshParts, 1) or data.maxMeshParts > budget[2]) then
		return bad("maxMeshParts")
	end
	if type(data.requiredAttachments) ~= "table" then
		return bad("requiredAttachments")
	end
	for _, name in ipairs(data.requiredAttachments) do
		if type(name) ~= "string" or string.match(name, "^%u%w*$") == nil then
			return bad("requiredAttachments")
		end
	end
	local upload = data.upload
	if
		type(upload) ~= "table"
		or not isOptionalString(upload.modelAssetId)
		or not isOptionalString(upload.sourceSha256)
		or not isOptionalString(upload.uploadedAt)
	then
		return bad("upload")
	end
	return data :: Spec, nil
end

-- The triangle and MeshPart limits of a spec: the tier default, or a lower value from the spec.
function AssetSpec.limits(spec: Spec): (number, number)
	local budget = Config.BUDGET[spec.tier]
	return spec.maxTriangles or budget[1], spec.maxMeshParts or budget[2]
end

-- Trees always need a TreeBase attachment on top of the spec's own list.
function AssetSpec.requiredAttachments(spec: Spec): { string }
	local names: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(name: string)
		if not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end
	if string.sub(spec.artPath, 1, 6) == "Trees/" then
		add("TreeBase")
	end
	for _, name in ipairs(spec.requiredAttachments) do
		add(name)
	end
	return names
end

local function quote(value: string): string
	return serde.encode("json", value)
end

local function nullable(value: string?): string
	return if value == nil then "null" else quote(value)
end

-- Fixed key order so version control shows only real changes.
function AssetSpec.encode(spec: Spec): string
	local lines = {
		"{",
		string.format('\t"schemaVersion": %d,', spec.schemaVersion),
		string.format('\t"artPath": %s,', quote(spec.artPath)),
		string.format('\t"displayName": %s,', quote(spec.displayName)),
		string.format('\t"tier": %s,', quote(spec.tier)),
		string.format('\t"version": %d,', spec.version),
	}
	if spec.maxTriangles ~= nil then
		table.insert(lines, string.format('\t"maxTriangles": %d,', spec.maxTriangles))
	end
	if spec.maxMeshParts ~= nil then
		table.insert(lines, string.format('\t"maxMeshParts": %d,', spec.maxMeshParts))
	end
	local attachments = {}
	for _, name in ipairs(spec.requiredAttachments) do
		table.insert(attachments, quote(name))
	end
	table.insert(lines, string.format('\t"requiredAttachments": [%s],', table.concat(attachments, ", ")))
	table.insert(lines, '\t"upload": {')
	table.insert(lines, string.format('\t\t"modelAssetId": %s,', nullable(spec.upload.modelAssetId)))
	table.insert(lines, string.format('\t\t"sourceSha256": %s,', nullable(spec.upload.sourceSha256)))
	table.insert(lines, string.format('\t\t"uploadedAt": %s', nullable(spec.upload.uploadedAt)))
	table.insert(lines, "\t}")
	table.insert(lines, "}")
	return table.concat(lines, "\n") .. "\n"
end

return AssetSpec
