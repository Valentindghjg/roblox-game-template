--!nonstrict
-- Turns the raw Roblox import of a Blender export into the normalized art Model.
-- Headless (Lune): it trusts neither the importer's axes nor its units; it derives scale
-- and yaw from report.json and fails with ART_AXIS_MISMATCH when no yaw fits.
local roblox = require("@lune/roblox")
local AssetSpec = require("./AssetSpec")
local Config = require("./Config")
local Paths = require("./Paths")

local CFrame, Color3, Content, Enum, Instance, Vector3 =
	roblox.CFrame, roblox.Color3, roblox.Content, roblox.Enum, roblox.Instance, roblox.Vector3

local Normalize = {}

local function vectorOf(values: { number }): any
	return Vector3.new(values[1], values[2], values[3])
end

local function rawBounds(meshParts: { any }): (any, any)
	local low, high = nil, nil
	for _, part in ipairs(meshParts) do
		local half = part.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = part.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
					low = if low == nil
						then corner
						else Vector3.new(
							math.min(low.X, corner.X),
							math.min(low.Y, corner.Y),
							math.min(low.Z, corner.Z)
						)
					high = if high == nil
						then corner
						else Vector3.new(
							math.max(high.X, corner.X),
							math.max(high.Y, corner.Y),
							math.max(high.Z, corner.Z)
						)
				end
			end
		end
	end
	return low, high
end

-- Tries one yaw candidate: every part centre and size must land on its report object.
local function fits(
	pairsList: { any },
	yaw: number,
	scale: number,
	rawCentre: any,
	reportCentre: any,
	tolerance: number
)
	local rotation = CFrame.Angles(0, math.rad(yaw), 0)
	for _, pair in ipairs(pairsList) do
		local part, object = pair.part, pair.object
		local mapped = rotation * ((part.CFrame.Position - rawCentre) * scale) + reportCentre
		local center = vectorOf(object.center)
		if
			math.abs(mapped.X - center.X) > tolerance
			or math.abs(mapped.Y - center.Y) > tolerance
			or math.abs(mapped.Z - center.Z) > tolerance
		then
			return false
		end
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = (rotation * part.CFrame):GetComponents()
		local size = part.Size * scale
		local extents = {
			math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z,
			math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z,
			math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z,
		}
		for axis = 1, 3 do
			if math.abs(extents[axis] - object.size[axis]) > tolerance then
				return false
			end
		end
	end
	return true
end

local function materialOf(name: string): any
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	return if ok then material else nil
end

-- Returns model, nil, nil, { yaw, scale } or nil, code, detail.
function Normalize.normalize(
	raw: { any },
	report: any,
	spec: any,
	palette: any,
	importYaw: number
): (any, string?, string?, any)
	-- 1. Scripts are never allowed in art; 2. only MeshParts survive.
	local meshParts = {}
	local function visit(instance: any): string?
		if instance:IsA("LuaSourceContainer") then
			return instance.Name
		end
		if instance:IsA("MeshPart") then
			table.insert(meshParts, instance)
		end
		return nil
	end
	for _, root in ipairs(raw) do
		local found = visit(root)
		if found then
			return nil, "ART_SCRIPT_FOUND", found
		end
		for _, descendant in ipairs(root:GetDescendants()) do
			found = visit(descendant)
			if found then
				return nil, "ART_SCRIPT_FOUND", found
			end
		end
	end

	-- 3. Match MeshParts to report objects by name, then check palette keys.
	local remaining = {}
	for _, object in ipairs(report.objects) do
		remaining[object.name] = object
	end
	local matched = {}
	for _, part in ipairs(meshParts) do
		local object = remaining[part.Name]
		if object == nil then
			return nil, "ART_UNKNOWN_PART", part.Name
		end
		remaining[part.Name] = nil
		table.insert(matched, { part = part, object = object })
	end
	for _, object in ipairs(report.objects) do
		if remaining[object.name] ~= nil then
			return nil, "ART_MISSING_PART", object.name
		end
	end
	for _, pair in ipairs(matched) do
		local partName, key = string.match(pair.object.name, "^(.-)__(.+)$")
		local entry = key and palette[key]
		if partName == nil or entry == nil or materialOf(entry.material) == nil then
			return nil, "ART_UNKNOWN_PALETTE", tostring(key or pair.object.name)
		end
		pair.partName = partName
		pair.entry = entry
	end

	-- 4. Budget.
	local maxTriangles, maxMeshParts = AssetSpec.limits(spec)
	if report.triangles > maxTriangles then
		return nil, "ART_BUDGET", string.format("triangles %d > %d", report.triangles, maxTriangles)
	end
	if #meshParts > maxMeshParts then
		return nil, "ART_BUDGET", string.format("meshParts %d > %d", #meshParts, maxMeshParts)
	end

	-- Required attachments are checked before anything is built.
	for _, name in ipairs(AssetSpec.requiredAttachments(spec)) do
		if report.attachments[name] == nil then
			return nil, "ART_MISSING_ATTACHMENT", name
		end
	end

	-- 5. Scale from the Y extent, then the first yaw that maps every part onto the report.
	local low, high = rawBounds(meshParts)
	local rawSize = high - low
	if rawSize.Y <= 1e-6 then
		return nil, "ART_AXIS_MISMATCH", "raw model has no height"
	end
	local scale = report.size[2] / rawSize.Y
	local rawCentre = (low + high) / 2
	local reportCentre = (vectorOf(report.bboxMin) + vectorOf(report.bboxMax)) / 2
	local tolerance =
		math.max(Config.MATCH_ABS, Config.MATCH_REL * math.max(report.size[1], report.size[2], report.size[3]))
	local candidates, seen = {}, {}
	for _, yaw in ipairs({ importYaw, 0, 90, 180, 270 }) do
		if not seen[yaw] then
			seen[yaw] = true
			table.insert(candidates, yaw)
		end
	end
	local detected = nil
	for _, yaw in ipairs(candidates) do
		if fits(matched, yaw, scale, rawCentre, reportCentre, tolerance) then
			detected = yaw
			break
		end
	end
	if detected == nil then
		return nil, "ART_AXIS_MISMATCH", string.format("no yaw of %s fits the report", table.concat(candidates, ", "))
	end
	local rotation = CFrame.Angles(0, math.rad(detected), 0)

	-- 6. Build the normalized model.
	local model = Instance.new("Model")
	model.Name = Paths.leaf(spec.artPath)
	local artRoot = Instance.new("Part")
	artRoot.Name = "ArtRoot"
	artRoot.Size = Vector3.new(Config.ART_ROOT_SIZE, Config.ART_ROOT_SIZE, Config.ART_ROOT_SIZE)
	artRoot.CFrame = CFrame.identity
	artRoot.Transparency = 1
	artRoot.CanCollide = false
	artRoot.CanQuery = false
	artRoot.CanTouch = false
	artRoot.Anchored = true
	artRoot.Parent = model
	model.PrimaryPart = artRoot

	local hasColliders = #report.colliders > 0
	for _, pair in ipairs(matched) do
		local part = pair.part
		local position = rotation * ((part.CFrame.Position - rawCentre) * scale) + reportCentre
		local rawRotation = part.CFrame.Rotation
		local size = part.Size * scale
		part:ClearAllChildren()
		part.Parent = nil
		part.Name = pair.partName
		part.Size = size
		part.CFrame = CFrame.new(position) * rotation * rawRotation
		part.Color = Color3.fromRGB(pair.entry.rgb[1], pair.entry.rgb[2], pair.entry.rgb[3])
		part.Material = materialOf(pair.entry.material)
		part.TextureContent = Content.none
		part.Anchored = true
		part.CastShadow = true
		part.CollisionFidelity = Enum.CollisionFidelity.Box
		part.CanCollide = not hasColliders
		part.Parent = model
	end

	for _, collider in ipairs(report.colliders) do
		local box = Instance.new("Part")
		box.Name = "Collider_" .. collider.name
		box.Size = vectorOf(collider.size)
		box.CFrame = CFrame.new(vectorOf(collider.center))
		box.Transparency = 1
		box.CanCollide = true
		box.CanQuery = false
		box.CanTouch = false
		box.Anchored = true
		box.Parent = model
	end

	local names = {}
	for name in pairs(report.attachments) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = vectorOf(report.attachments[name])
		attachment.Parent = artRoot
	end

	model:SetAttribute("ArtAssetId", Paths.leaf(spec.artPath))
	model:SetAttribute("ArtPath", spec.artPath)
	model:SetAttribute("ArtSource", "blender")
	model:SetAttribute("ArtVersion", spec.version)
	model:SetAttribute("ArtTier", spec.tier)
	return model, nil, nil, { yaw = detected, scale = scale }
end

return Normalize
