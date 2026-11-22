--!nonstrict
-- Headless tests of the art pipeline: normalizer, verifier, Open Cloud client with
-- fake HTTP, asset spec, a real `rojo build`, and (when Blender is installed) the exporter.
-- Run: lune run tests/tools/art_pipeline.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local ArtPalette = require("../../src/shared/ArtPalette")
local AssetSpec = require("../../tools/art/lib/AssetSpec")
local Blender = require("../../tools/art/lib/Blender")
local Config = require("../../tools/art/lib/Config")
local Normalize = require("../../tools/art/lib/Normalize")
local OpenCloud = require("../../tools/art/lib/OpenCloud")
local Paths = require("../../tools/art/lib/Paths")
local Verify = require("../../tools/art/lib/Verify")

local CFrame, Color3, Content, Enum, Instance, Vector3 =
	roblox.CFrame, roblox.Color3, roblox.Content, roblox.Enum, roblox.Instance, roblox.Vector3

local FIXTURE_ROOT = "tests/fixtures/art"
local PROBE_PATH = "Props/ArtPipelineProbe"

-- Harness ---------------------------------------------------------------------------------------
local run, passed, failed, skipped = 0, 0, 0, 0
local function test(name: string, fn: () -> ())
	run += 1
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(string.format("[ART-TEST] PASS %s", name))
	else
		failed += 1
		print(string.format("[ART-TEST] FAIL %s | %s", name, tostring(err)))
	end
end
local function skip(name: string, reason: string)
	run += 1
	skipped += 1
	print(string.format("[ART-TEST] SKIP %s | %s", name, reason))
end

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end
local function near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"%sexpected %s +-%s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(tolerance),
				tostring(actual)
			),
			2
		)
	end
end
local function truthy(value: any, label: string?)
	if not value then
		error((label or "expected truthy") .. ", got " .. tostring(value), 2)
	end
end

-- Fixtures --------------------------------------------------------------------------------------
local function vectorOf(values: { number }): any
	return Vector3.new(values[1], values[2], values[3])
end

-- Report of the generated probe (Roblox axes, studs).
local function probeReport(): any
	return {
		schemaVersion = 1,
		blenderVersion = "test",
		size = { 4, 3.5, 5 },
		bboxMin = { -2, 0, -3 },
		bboxMax = { 2, 3.5, 2 },
		triangles = 36,
		objects = {
			{ name = "Body__WoodWarm", center = { 0, 1.5, 0 }, size = { 4, 3, 4 }, triangles = 12 },
			{ name = "Nose__RoofRed", center = { 0, 1.5, -2.5 }, size = { 1, 1, 1 }, triangles = 12 },
			{ name = "Top__SnowWhite", center = { -1, 3.25, 0 }, size = { 2, 0.5, 2 }, triangles = 12 },
		},
		attachments = { Front = { 0, 0, -3 } },
		colliders = { { name = "Body", center = { 0, 1.5, 0 }, size = { 4, 3, 4 } } },
	}
end

local function probeSpec(): any
	return {
		schemaVersion = 1,
		artPath = PROBE_PATH,
		displayName = "Art pipeline probe",
		tier = "B",
		version = 1,
		requiredAttachments = { "Front" },
		upload = {},
	}
end

-- Builds the raw import of a report: parts shifted by `offset`, scaled by 1/scale, turned by
-- -yaw (so Normalize has to find `yaw` again), optionally mirrored along X.
local function makeRaw(report: any, options: any?): any
	options = options or {}
	local yaw = options.yaw or 0
	local scale = options.scale or 1
	local reportCentre = (vectorOf(report.bboxMin) + vectorOf(report.bboxMax)) / 2
	local rawCentre = options.offset or reportCentre
	local inverse = CFrame.Angles(0, math.rad(yaw), 0):Inverse()
	local wrapper = Instance.new("Model")
	wrapper.Name = "RawImport"
	for _, object in ipairs(report.objects) do
		local part = Instance.new("MeshPart")
		part.Name = object.name
		local position = inverse * ((vectorOf(object.center) - reportCentre) / scale) + rawCentre
		if options.mirror then
			position = Vector3.new(2 * rawCentre.X - position.X, position.Y, position.Z)
		end
		local size = vectorOf(object.size) / scale
		if yaw % 180 == 90 then
			size = Vector3.new(size.Z, size.Y, size.X)
		end
		part.Size = size
		part.CFrame = CFrame.new(position)
		part.MeshContent = Content.fromUri("rbxassetid://1001")
		part.Parent = wrapper
	end
	return wrapper
end

local function normalized(report: any, spec: any, raw: any): any
	local model, code, detail, info = Normalize.normalize({ raw }, report, spec, ArtPalette, 0)
	if model == nil then
		error(string.format("normalize failed: %s %s", tostring(code), tostring(detail)), 2)
	end
	return model, info
end

local function failureOf(report: any, spec: any, raw: any): (string?, string?)
	local model, code, detail = Normalize.normalize({ raw }, report, spec, ArtPalette, 0)
	eq(model, nil, "expected a failure")
	return code, detail
end

local function partOf(model: any, name: string): any
	local part = model:FindFirstChild(name)
	truthy(part, "missing part " .. name)
	return part
end

local function checkIdentity(cframe: any)
	local components = { cframe:GetComponents() }
	local identity = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	for index, expected in ipairs(identity) do
		near(components[index], expected, 1e-4, "CFrame component " .. index)
	end
end

local function placeWith(model: any, artPath: string): any
	local place = Instance.new("DataModel")
	local folder = Instance.new("Folder")
	folder.Name = "ArtAssets"
	folder.Parent = place:GetService("ReplicatedStorage")
	local parent = folder
	local segments = {}
	for segment in string.gmatch(artPath, "[^/]+") do
		table.insert(segments, segment)
	end
	for index = 1, #segments - 1 do
		local category = Instance.new("Folder")
		category.Name = segments[index]
		category.Parent = parent
		parent = category
	end
	model.Parent = parent
	return place
end

local function codes(failures: { any }): { string }
	local list = {}
	for _, failure in ipairs(failures) do
		table.insert(list, failure.code)
	end
	return list
end

-- Normalize -------------------------------------------------------------------------------------
test("N1 identity import normalizes to the report", function()
	local report = probeReport()
	local model, info = normalized(report, probeSpec(), makeRaw(report))
	eq(model.Name, "ArtPipelineProbe")
	eq(info.yaw, 0)
	near(info.scale, 1, 1e-4)
	local root = model.PrimaryPart
	eq(root and root.Name, "ArtRoot")
	checkIdentity(root.CFrame)
	near(root.Size.X, 0.05, 1e-3)
	eq(root.Transparency, 1)
	eq(root.Anchored, true)
	eq(root.CanCollide, false)
	eq(root.CanQuery, false)
	eq(root.CanTouch, false)
	for _, object in ipairs(report.objects) do
		local partName, key = string.match(object.name, "^(.-)__(.+)$")
		local part = partOf(model, partName)
		eq(part.ClassName, "MeshPart")
		eq(part.Color, Color3.fromRGB(ArtPalette[key].rgb[1], ArtPalette[key].rgb[2], ArtPalette[key].rgb[3]), partName)
		eq(part.Material, Enum.Material.SmoothPlastic, partName)
		eq(part.Anchored, true)
		eq(part.MeshContent.Uri, "rbxassetid://1001")
		for axis, name in ipairs({ "X", "Y", "Z" }) do
			near(part.CFrame.Position[name], object.center[axis], 1e-3, partName .. " centre " .. name)
			near(part.Size[name], object.size[axis], 1e-3, partName .. " size " .. name)
		end
	end
	eq(model:GetAttribute("ArtAssetId"), "ArtPipelineProbe")
	eq(model:GetAttribute("ArtPath"), PROBE_PATH)
	eq(model:GetAttribute("ArtSource"), "blender")
	eq(model:GetAttribute("ArtVersion"), 1)
	eq(model:GetAttribute("ArtTier"), "B")
end)

test("N2 yaw 180, scale 0.5 and an offset are detected and undone", function()
	local report = probeReport()
	local raw = makeRaw(report, { yaw = 180, scale = 0.5, offset = Vector3.new(10, -3, 7) })
	local model, info = normalized(report, probeSpec(), raw)
	eq(info.yaw, 180)
	near(info.scale, 0.5, 1e-3)
	for _, object in ipairs(report.objects) do
		local part = partOf(model, string.match(object.name, "^(.-)__"))
		for axis, name in ipairs({ "X", "Y", "Z" }) do
			near(part.CFrame.Position[name], object.center[axis], 2e-3, object.name .. " centre " .. name)
			near(part.Size[name], object.size[axis], 2e-3, object.name .. " size " .. name)
		end
	end
	local expected = { CFrame.Angles(0, math.rad(180), 0):GetComponents() }
	local actual = { partOf(model, "Body").CFrame:GetComponents() }
	for index = 4, 12 do
		near(actual[index], expected[index], 1e-4, "rotation " .. index)
	end
end)

test("N3 yaw 90 is detected", function()
	local report = probeReport()
	local raw = makeRaw(report, { yaw = 90, offset = Vector3.new(-5, 2, 3) })
	local model, info = normalized(report, probeSpec(), raw)
	eq(info.yaw, 90)
	near(info.scale, 1, 1e-3)
	for _, object in ipairs(report.objects) do
		local part = partOf(model, string.match(object.name, "^(.-)__"))
		for axis, name in ipairs({ "X", "Y", "Z" }) do
			near(part.CFrame.Position[name], object.center[axis], 2e-3, object.name .. " centre " .. name)
		end
	end
	local expected = { CFrame.Angles(0, math.rad(90), 0):GetComponents() }
	local actual = { partOf(model, "Top").CFrame:GetComponents() }
	for index = 4, 12 do
		near(actual[index], expected[index], 1e-4, "rotation " .. index)
	end
end)

test("N4 a mirrored import fails with ART_AXIS_MISMATCH", function()
	local report = probeReport()
	local code = failureOf(report, probeSpec(), makeRaw(report, { mirror = true }))
	eq(code, "ART_AXIS_MISMATCH")
end)

test("N5 an unknown palette key fails with ART_UNKNOWN_PALETTE", function()
	local report = probeReport()
	report.objects[1].name = "Body__Unobtainium"
	local code, detail = failureOf(report, probeSpec(), makeRaw(report))
	eq(code, "ART_UNKNOWN_PALETTE")
	eq(detail, "Unobtainium")
end)

test("N6 unmatched parts fail with ART_UNKNOWN_PART and ART_MISSING_PART", function()
	local report = probeReport()
	local raw = makeRaw(report)
	local stray = Instance.new("MeshPart")
	stray.Name = "Stray__WoodWarm"
	stray.Parent = raw
	local code, detail = failureOf(report, probeSpec(), raw)
	eq(code, "ART_UNKNOWN_PART")
	eq(detail, "Stray__WoodWarm")
	local missing = makeRaw(report)
	partOf(missing, "Nose__RoofRed"):Destroy()
	code, detail = failureOf(report, probeSpec(), missing)
	eq(code, "ART_MISSING_PART")
	eq(detail, "Nose__RoofRed")
end)

test("N7 scripts are rejected and textures are stripped", function()
	local report = probeReport()
	local raw = makeRaw(report)
	local script = Instance.new("Script")
	script.Name = "Sneaky"
	script.Parent = partOf(raw, "Body__WoodWarm")
	local code, detail = failureOf(report, probeSpec(), raw)
	eq(code, "ART_SCRIPT_FOUND")
	eq(detail, "Sneaky")

	local textured = makeRaw(report)
	Instance.new("SurfaceAppearance").Parent = partOf(textured, "Body__WoodWarm")
	Instance.new("Decal").Parent = partOf(textured, "Top__SnowWhite")
	local model = normalized(report, probeSpec(), textured)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.ClassName == "SurfaceAppearance" or descendant.ClassName == "Decal" then
			error("texture survived: " .. descendant.ClassName)
		end
	end
	eq(model:FindFirstChild("RawImport"), nil)
end)

test("N8 triangle and MeshPart budgets fail with ART_BUDGET", function()
	local report = probeReport()
	local spec = probeSpec()
	spec.maxTriangles = 30
	local code, detail = failureOf(report, spec, makeRaw(report))
	eq(code, "ART_BUDGET")
	truthy(string.find(detail, "triangles", 1, true), "detail names triangles")
	spec = probeSpec()
	spec.maxMeshParts = 2
	code, detail = failureOf(report, spec, makeRaw(report))
	eq(code, "ART_BUDGET")
	truthy(string.find(detail, "meshParts", 1, true), "detail names meshParts")
	-- The tier default applies without a spec limit: tier B allows 1000 triangles.
	report.triangles = 1001
	code = failureOf(report, probeSpec(), makeRaw(report))
	eq(code, "ART_BUDGET")
end)

test("N9 colliders switch the MeshPart collision", function()
	local report = probeReport()
	local withColliders = normalized(report, probeSpec(), makeRaw(report))
	for _, name in ipairs({ "Body", "Nose", "Top" }) do
		eq(partOf(withColliders, name).CanCollide, false, name)
	end
	local collider = partOf(withColliders, "Collider_Body")
	eq(collider.ClassName, "Part")
	eq(collider.Transparency, 1)
	eq(collider.CanCollide, true)
	eq(collider.CanQuery, false)
	eq(collider.CanTouch, false)
	eq(collider.Anchored, true)
	near(collider.Size.Y, 3, 1e-3)
	near(collider.CFrame.Position.Y, 1.5, 1e-3)

	local bare = probeReport()
	bare.colliders = {}
	local withoutColliders = normalized(bare, probeSpec(), makeRaw(bare))
	for _, name in ipairs({ "Body", "Nose", "Top" }) do
		eq(partOf(withoutColliders, name).CanCollide, true, name)
	end
	eq(withoutColliders:FindFirstChild("Collider_Body"), nil)
end)

test("N10 attachments are created and required ones are enforced", function()
	local report = probeReport()
	local model = normalized(report, probeSpec(), makeRaw(report))
	local attachment = model.PrimaryPart:FindFirstChild("Front")
	truthy(attachment and attachment.ClassName == "Attachment", "Front attachment")
	near(attachment.Position.Z, -3, 1e-3)

	local noFront = probeReport()
	noFront.attachments = {}
	local code, detail = failureOf(noFront, probeSpec(), makeRaw(noFront))
	eq(code, "ART_MISSING_ATTACHMENT")
	eq(detail, "Front")

	-- Trees always need TreeBase, even when asset.json lists nothing.
	local treeSpec = probeSpec()
	treeSpec.artPath = "Trees/DouglasFir/Medium"
	treeSpec.requiredAttachments = {}
	code, detail = failureOf(report, treeSpec, makeRaw(report))
	eq(code, "ART_MISSING_ATTACHMENT")
	eq(detail, "TreeBase")
	local treeReport = probeReport()
	treeReport.attachments.TreeBase = { 0, 0, 0 }
	local tree = normalized(treeReport, treeSpec, makeRaw(treeReport))
	eq(tree.Name, "Medium")
	truthy(tree.PrimaryPart:FindFirstChild("TreeBase"), "TreeBase attachment")
end)

test("N11 a serialized model survives a round trip and passes verifyPlace", function()
	local report = probeReport()
	local model = normalized(report, probeSpec(), makeRaw(report))
	local back = roblox.deserializeModel(roblox.serializeModel({ model }))[1]
	local place = placeWith(back, PROBE_PATH)
	local failures = Verify.verifyPlace(place, { { artPath = PROBE_PATH, spec = probeSpec(), hasRbxm = true } })
	eq(#failures, 0, table.concat(codes(failures), ","))
end)

-- Verify ----------------------------------------------------------------------------------------
test("V1 verifyPlace reports a missing asset", function()
	local place = Instance.new("DataModel")
	local failures = Verify.verifyPlace(place, {
		{ artPath = PROBE_PATH, spec = probeSpec(), hasRbxm = true },
		{ artPath = "Props/Pending", spec = probeSpec(), hasRbxm = false },
	})
	eq(#failures, 1)
	eq(failures[1].code, "MissingArtAsset")
	eq(failures[1].artPath, PROBE_PATH)
end)

test("V2 verifyPlace reports empty meshes and a stale version", function()
	local report = probeReport()
	local model = normalized(report, probeSpec(), makeRaw(report))
	partOf(model, "Nose").MeshContent = Content.none
	local spec = probeSpec()
	spec.version = 2
	local place = placeWith(model, PROBE_PATH)
	local found = codes(Verify.verifyPlace(place, { { artPath = PROBE_PATH, spec = spec, hasRbxm = true } }))
	table.sort(found)
	eq(table.concat(found, ","), "ART_BAD_MESH,ART_VERSION_MISMATCH")
end)

test("V3 verifyFiles flags an orphan .rbxm and lists pending specs", function()
	local failures, pending = Verify.verifyFiles({ "Props/Orphan", "Props/Done" }, { "Props/Done", "Props/Later" })
	eq(#failures, 1)
	eq(failures[1].code, "ART_ORPHAN_RBXM")
	eq(failures[1].artPath, "Props/Orphan")
	eq(table.concat(pending, ","), "Props/Later")
end)

-- OpenCloud (fake HTTP) -------------------------------------------------------------------------
local KEY = "TEST-KEY-do-not-print-123"
local session = { apiKey = KEY, creator = { userId = "42" } }

-- handler(request, callNumber) -> response table or nil, message
local function fakeDeps(handler: (any, number) -> (any, string?))
	local log, sleeps = {}, {}
	local deps = {
		request = function(req: any)
			table.insert(log, req)
			return handler(req, #log)
		end,
		sleep = function(seconds: number)
			table.insert(sleeps, seconds)
		end,
	}
	return deps, log, sleeps
end

local function json(status: number, value: any): any
	return { status = status, body = serde.encode("json", value), headers = {} }
end

local function assertNoKey(...: any)
	for _, value in ipairs({ ... }) do
		if type(value) == "string" and string.find(value, KEY, 1, true) then
			error("API key leaked into a result")
		end
	end
end

test("O1 upload posts the FBX, polls and returns the asset id", function()
	local deps, log, sleeps = fakeDeps(function(req, call)
		if req.method == "POST" then
			return json(200, { path = "operations/op1", done = false })
		end
		if call < 3 then
			return json(200, { path = "operations/op1", done = false })
		end
		return json(200, { path = "operations/op1", done = true, response = { assetId = "123" } })
	end)
	local assetId, code, detail = OpenCloud.upload(deps, session, PROBE_PATH, "Probe", "FBXBYTES")
	eq(assetId, "123")
	eq(code, nil)
	assertNoKey(assetId, code, detail)
	eq(#log, 3)
	eq(log[1].url, Config.ASSETS_URL)
	eq(log[1].headers["x-api-key"], KEY)
	truthy(
		string.find(
			log[1].headers["Content-Type"],
			"^multipart/form%-data; boundary=gameart%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$"
		),
		"boundary"
	)
	truthy(string.find(log[1].body, '"assetType":"Model"', 1, true), "assetType")
	truthy(string.find(log[1].body, '"userId":"42"', 1, true), "creator")
	truthy(string.find(log[1].body, "model/fbx", 1, true), "content type")
	truthy(string.find(log[1].body, "FBXBYTES", 1, true), "file bytes")
	eq(log[2].url, Config.OPERATIONS_URL .. "op1")
	eq(log[2].method, "GET")
	eq(#sleeps, 2)
	eq(sleeps[1], Config.POLL_SECONDS)
end)

test("O2 upload failures, rate limits, timeouts and ambiguity", function()
	-- 401 is a failure, and the key never shows even when the server echoes it.
	local deps = fakeDeps(function()
		return { status = 401, body = "bad key " .. KEY, headers = {} }
	end)
	local assetId, code, detail = OpenCloud.upload(deps, session, PROBE_PATH, "Probe", "x")
	eq(assetId, nil)
	eq(code, "ART_UPLOAD_FAILED")
	truthy(string.find(detail, "^401"), "status in detail")
	assertNoKey(code, detail)

	-- 429 three times, then success.
	local rateDeps, rateLog, rateSleeps = fakeDeps(function(_, call)
		if call <= 3 then
			return { status = 429, body = "slow down", headers = { ["Retry-After"] = "7" } }
		end
		return json(200, { done = true, response = { assetId = 777 } })
	end)
	assetId, code = OpenCloud.upload(rateDeps, session, PROBE_PATH, "Probe", "x")
	eq(assetId, "777")
	eq(#rateLog, 4)
	eq(#rateSleeps, 3)
	eq(rateSleeps[1], 7)
	-- A fourth 429 gives up.
	local stuck = fakeDeps(function()
		return { status = 429, body = "no", headers = {} }
	end)
	assetId, code, detail = OpenCloud.upload(stuck, session, PROBE_PATH, "Probe", "x")
	eq(code, "ART_UPLOAD_FAILED")
	truthy(string.find(detail, "^429"), "429 in detail")

	-- Sixty polls without a result time out.
	local pollDeps, pollLog = fakeDeps(function()
		return json(200, { path = "operations/op2", done = false })
	end)
	assetId, code = OpenCloud.upload(pollDeps, session, PROBE_PATH, "Probe", "x")
	eq(code, "ART_UPLOAD_TIMEOUT")
	eq(#pollLog, 1 + Config.MAX_POLLS)

	-- An operation error is a failure.
	local errorDeps = fakeDeps(function()
		return json(200, { path = "operations/op3", done = true, error = { code = 3, message = "bad mesh" } })
	end)
	assetId, code, detail = OpenCloud.upload(errorDeps, session, PROBE_PATH, "Probe", "x")
	eq(code, "ART_UPLOAD_FAILED")
	truthy(string.find(detail, "bad mesh", 1, true), "operation error text")

	-- A transport error is ambiguous and never retried.
	local lostDeps, lostLog = fakeDeps(function()
		return nil, "connection reset"
	end)
	assetId, code = OpenCloud.upload(lostDeps, session, PROBE_PATH, "Probe", "x")
	eq(code, "ART_UPLOAD_AMBIGUOUS")
	eq(#lostLog, 1)
end)

test("O3 download follows the delivery location and retries", function()
	local deps, log = fakeDeps(function(req)
		if req.url == Config.DELIVERY_URL .. "123" then
			eq(req.headers["x-api-key"], KEY)
			return json(200, { location = "https://cdn.example/model" })
		end
		eq(req.url, "https://cdn.example/model")
		eq(req.headers["x-api-key"], nil, "the CDN request must not carry the key")
		return { status = 200, body = "RBXMBYTES", headers = {} }
	end)
	local bytes, code = OpenCloud.download(deps, session, "123")
	eq(bytes, "RBXMBYTES")
	eq(code, nil)
	eq(#log, 2)

	local missing, missingLog, sleeps = fakeDeps(function()
		return { status = 404, body = "not found", headers = {} }
	end)
	local nothing, failure, detail = OpenCloud.download(missing, session, "123")
	eq(nothing, nil)
	eq(failure, "ART_DOWNLOAD_FAILED")
	assertNoKey(failure, detail)
	eq(#missingLog, Config.DOWNLOAD_RETRIES)
	eq(#sleeps, Config.DOWNLOAD_RETRIES - 1)
end)

-- AssetSpec -------------------------------------------------------------------------------------
test("S1 asset specs are validated with ART_BAD_SPEC <field>", function()
	local function problem(mutate: (any) -> ()): string?
		local spec = probeSpec()
		mutate(spec)
		local _, message = AssetSpec.validate(spec, nil)
		return message
	end
	eq(
		problem(function(spec)
			spec.schemaVersion = 2
		end),
		"ART_BAD_SPEC schemaVersion"
	)
	eq(
		problem(function(spec)
			spec.tier = "C"
		end),
		"ART_BAD_SPEC tier"
	)
	eq(
		problem(function(spec)
			spec.artPath = "props/probe"
		end),
		"ART_BAD_SPEC artPath"
	)
	eq(
		problem(function(spec)
			spec.version = 0
		end),
		"ART_BAD_SPEC version"
	)
	eq(
		problem(function(spec)
			spec.maxTriangles = 5000
		end),
		"ART_BAD_SPEC maxTriangles"
	)
	eq(problem(function() end), nil)
	local spec = AssetSpec.validate(probeSpec(), PROBE_PATH)
	truthy(spec, "valid spec")
	local _, mismatch = AssetSpec.validate(probeSpec(), "Props/Other")
	eq(mismatch, "ART_BAD_SPEC artPath")
	-- The encoder round-trips with a stable layout.
	local text = AssetSpec.encode(spec)
	local again = AssetSpec.validate(serde.decode("json", text), PROBE_PATH)
	truthy(again, "encoded spec decodes")
	eq(AssetSpec.encode(again), text)
	-- The committed probe spec is itself valid.
	local committed = AssetSpec.validate(
		serde.decode("json", fs.readFile(FIXTURE_ROOT .. "/source/" .. PROBE_PATH .. "/asset.json")),
		PROBE_PATH
	)
	truthy(committed, "committed probe asset.json")
end)

-- Rojo ------------------------------------------------------------------------------------------
test("R1 rojo maps an .rbxm into ReplicatedStorage.ArtAssets", function()
	local dir = FIXTURE_ROOT .. "/_build/rojo"
	if fs.isDir(dir) then
		fs.removeDir(dir)
	end
	fs.writeDir(dir .. "/rbxm/Props")
	local report = probeReport()
	local model = normalized(report, probeSpec(), makeRaw(report))
	fs.writeFile(dir .. "/rbxm/" .. PROBE_PATH .. ".rbxm", roblox.serializeModel({ model }))
	fs.writeFile(
		dir .. "/default.project.json",
		serde.encode("json", {
			name = "ArtRojoTest",
			tree = {
				["$className"] = "DataModel",
				ReplicatedStorage = {
					["$className"] = "ReplicatedStorage",
					ArtAssets = { ["$path"] = "rbxm", ["$ignoreUnknownInstances"] = true },
				},
			},
		})
	)
	local result = process.exec("rojo", { "build", dir .. "/default.project.json", "--output", dir .. "/out.rbxlx" })
	truthy(result.ok, "rojo build failed: " .. result.stderr)
	local place = roblox.deserializePlace(fs.readFile(dir .. "/out.rbxlx"))
	local failures = Verify.verifyPlace(place, { { artPath = PROBE_PATH, spec = probeSpec(), hasRbxm = true } })
	fs.removeDir(dir)
	eq(#failures, 0, table.concat(codes(failures), ","))
end)

-- Blender ---------------------------------------------------------------------------------------
local blender = Blender.resolve()
if blender == nil then
	skip("B1 make_probe and export", "Blender is not installed (" .. Blender.MISSING_CODE .. ")")
else
	test("B1 make_probe and export", function()
		local blendFile = Paths.blendFile(FIXTURE_ROOT, PROBE_PATH)
		local buildDir = Paths.buildDir(FIXTURE_ROOT, PROBE_PATH)
		fs.writeDir(buildDir)
		local made = Blender.run(blender, nil, "tools/art/make_probe.py", { "--out", blendFile })
		eq(made.code, 0, "make_probe exit code")
		local exported = Blender.run(blender, blendFile, "tools/art/blender_export.py", {
			"--fbx",
			buildDir .. "/model.fbx",
			"--report",
			buildDir .. "/report.json",
		})
		eq(exported.code, 0, "export exit code")
		truthy(fs.isFile(buildDir .. "/model.fbx"), "model.fbx")
		local report = serde.decode("json", fs.readFile(buildDir .. "/report.json"))
		eq(#report.objects, 3)
		eq(report.triangles, 36)
		truthy(report.attachments.Front, "attachment Front")
		near(report.size[1], 4, 1e-3)
		near(report.size[2], 3.5, 1e-3)
		near(report.size[3], 5, 1e-3)
		fs.removeFile(blendFile)
		fs.removeDir(FIXTURE_ROOT .. "/_build")
	end)
end

print(string.format("[ART-TEST] SUMMARY %d run, %d passed, %d failed, %d skipped", run, passed, failed, skipped))
if failed > 0 then
	process.exit(1)
end
