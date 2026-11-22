--!nonstrict
-- Art pipeline CLI: .blend -> FBX -> Roblox mesh -> normalized .rbxm.
-- Run from the repository root:  lune run tools/art/art.luau <command> [args]
--   doctor                     Blender, API key and creator status (exit 0 / 2 / 1)
--   export <artPath>           .blend -> _build/<artPath>/model.fbx + report.json
--   render <artPath>           Workbench previews, no upload needed
--   upload <artPath> [--force] FBX -> Open Cloud -> _build/<artPath>/raw.rbxm
--   normalize <artPath> [--raw <file>]
--   build <artPath>            export, upload, normalize
--   verify <placeFile>         integrated art vs the built place
--   probe                      the generated pipeline probe, end to end
-- Every command takes --root <dir> (default assets/art). Exit codes: 0 ok, 1 error,
-- 2 missing API key or creator.
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local ArtPalette = require("../../src/shared/ArtPalette")
local AssetSpec = require("./lib/AssetSpec")
local Blender = require("./lib/Blender")
local Config = require("./lib/Config")
local OpenCloud = require("./lib/OpenCloud")
local Normalize = require("./lib/Normalize")
local Paths = require("./lib/Paths")
local Verify = require("./lib/Verify")

local PROBE_ROOT = "tests/fixtures/art"
local PROBE_PATH = "Props/ArtPipelineProbe"
local EXPORT_SCRIPT = "tools/art/blender_export.py"
local RENDER_SCRIPT = "tools/art/blender_render.py"
local PROBE_SCRIPT = "tools/art/make_probe.py"
local NO_KEY_MESSAGE = "ART_NO_API_KEY: set ROBLOX_OPEN_CLOUD_API_KEY and ART_CREATOR (README, Art pipeline setup)"

local function die(message: string, code: number?)
	stdio.ewrite(message .. "\n")
	process.exit(code or 1)
end

-- Argument parsing ---------------------------------------------------------------------------
local positional: { string } = {}
local options: { [string]: string | boolean } = {}
do
	local args = process.args
	local index = 1
	while index <= #args do
		local value = args[index]
		if value == "--root" or value == "--raw" then
			options[value] = args[index + 1]
			index += 2
		elseif value == "--force" then
			options[value] = true
			index += 1
		else
			table.insert(positional, value)
			index += 1
		end
	end
end
local command = positional[1]
local root: string = if type(options["--root"]) == "string" then options["--root"] :: string else Paths.DEFAULT_ROOT

-- Helpers -------------------------------------------------------------------------------------
local function requireArtPath(): string
	local artPath = positional[2]
	if artPath == nil or not Paths.isValid(artPath) then
		die("ART_BAD_PATH: expected an art path such as Buildings/MarketStarter, got " .. tostring(artPath))
	end
	return artPath
end

local function loadSpec(rootDir: string, artPath: string): any
	local file = Paths.specFile(rootDir, artPath)
	if not fs.isFile(file) then
		die("ART_BAD_SPEC file " .. file)
	end
	local ok, data = pcall(serde.decode, "json", fs.readFile(file))
	if not ok then
		die("ART_BAD_SPEC json " .. file)
	end
	local spec, problem = AssetSpec.validate(data, artPath)
	if spec == nil then
		die(problem :: string)
	end
	return spec
end

local function requireBlender(): string
	local blender = Blender.resolve()
	if blender == nil then
		die(Blender.MISSING_CODE .. ": " .. Blender.MISSING_HINT)
	end
	return blender :: string
end

local function requireBlend(rootDir: string, artPath: string): string
	local blendFile = Paths.blendFile(rootDir, artPath)
	if not fs.isFile(blendFile) then
		die("ART_NO_BLEND: " .. blendFile)
	end
	return blendFile
end

local function showBlenderFailure(what: string, result: any)
	for _, line in ipairs(Blender.artLines(result)) do
		stdio.ewrite(line .. "\n")
	end
	die(string.format("ART_%s_FAILED: Blender exit code %d", what, result.code))
end

local function readSession(): any
	local key = process.env.ROBLOX_OPEN_CLOUD_API_KEY
	local creator = OpenCloud.parseCreator(process.env.ART_CREATOR)
	if key == nil or key == "" or creator == nil then
		return nil
	end
	return { apiKey = key, creator = creator }
end

local deps = {
	request = function(req: any): (any, string?)
		local ok, response = pcall(net.request, {
			url = req.url,
			method = req.method,
			headers = req.headers,
			body = req.body,
		})
		if not ok then
			return nil, tostring(response)
		end
		return { status = response.statusCode, body = response.body, headers = response.headers }, nil
	end,
	sleep = function(seconds: number)
		task.wait(seconds)
	end,
}

local function scan(dir: string, prefix: string, matchFile: (string) -> string?, found: { string })
	if not fs.isDir(dir) then
		return
	end
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path, prefix .. name .. "/", matchFile, found)
		else
			local stem = matchFile(name)
			if stem ~= nil then
				table.insert(found, if stem == "" then string.sub(prefix, 1, -2) else prefix .. stem)
			end
		end
	end
end

local function listSpecs(rootDir: string): { string }
	local found: { string } = {}
	scan(rootDir .. "/source", "", function(name)
		return if name == "asset.json" then "" else nil
	end, found)
	table.sort(found)
	return found
end

local function listRbxm(rootDir: string): { string }
	local found: { string } = {}
	scan(rootDir .. "/rbxm", "", function(name)
		return string.match(name, "^(.+)%.rbxm$")
	end, found)
	table.sort(found)
	return found
end

-- Commands --------------------------------------------------------------------------------------
local function doctor()
	local blender = Blender.resolve()
	local session = readSession()
	local creator = process.env.ART_CREATOR
	if blender ~= nil then
		print(string.format("Blender: %s (%s)", blender, Blender.version(blender) or "unknown version"))
	else
		print("Blender: missing (" .. Blender.MISSING_CODE .. ": " .. Blender.MISSING_HINT .. ")")
	end
	local keySet = process.env.ROBLOX_OPEN_CLOUD_API_KEY ~= nil and process.env.ROBLOX_OPEN_CLOUD_API_KEY ~= ""
	print("API key: " .. (if keySet then "set" else "missing"))
	print("Creator: " .. (if creator ~= nil and creator ~= "" then creator else "missing"))
	if blender == nil then
		process.exit(1)
	end
	if session == nil then
		process.exit(2)
	end
	process.exit(0)
end

local function exportArt(rootDir: string, artPath: string)
	loadSpec(rootDir, artPath)
	local blender = requireBlender()
	local buildDir = Paths.buildDir(rootDir, artPath)
	fs.writeDir(buildDir)
	local result = Blender.run(blender, requireBlend(rootDir, artPath), EXPORT_SCRIPT, {
		"--fbx",
		buildDir .. "/model.fbx",
		"--report",
		buildDir .. "/report.json",
	})
	if result.code ~= 0 then
		showBlenderFailure("EXPORT", result)
	end
	print(string.format("[ART] exported %s to %s/model.fbx", artPath, buildDir))
end

local function renderArt(rootDir: string, artPath: string)
	loadSpec(rootDir, artPath)
	local blender = requireBlender()
	local buildDir = Paths.buildDir(rootDir, artPath)
	fs.writeDir(buildDir)
	local extra = { "--out-dir", buildDir, "--colors" }
	local keys = {}
	for key in pairs(ArtPalette) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local rgb = ArtPalette[key].rgb
		table.insert(extra, string.format("%s=%d,%d,%d", key, rgb[1], rgb[2], rgb[3]))
	end
	local result = Blender.run(blender, requireBlend(rootDir, artPath), RENDER_SCRIPT, extra)
	if result.code ~= 0 then
		showBlenderFailure("RENDER", result)
	end
	print(string.format("[ART] rendered %s to %s/preview_front.png and preview_34.png", artPath, buildDir))
end

-- Returns the asset id of the uploaded (or previously recorded) model.
local function uploadArt(rootDir: string, artPath: string, force: boolean): string
	local session = readSession()
	if session == nil then
		die(NO_KEY_MESSAGE, 2)
	end
	local spec = loadSpec(rootDir, artPath)
	local blendFile = requireBlend(rootDir, artPath)
	local sha = serde.hash("sha256", fs.readFile(blendFile))
	local buildDir = Paths.buildDir(rootDir, artPath)
	local assetId = spec.upload.modelAssetId
	if force or spec.upload.sourceSha256 ~= sha or assetId == nil then
		local fbxFile = buildDir .. "/model.fbx"
		if not fs.isFile(fbxFile) then
			die("ART_NO_FBX: run export first (" .. fbxFile .. ")")
		end
		local uploaded, code, detail = OpenCloud.upload(deps, session, artPath, spec.displayName, fs.readFile(fbxFile))
		if uploaded == nil then
			die(string.format("%s %s", code :: string, detail or ""))
		end
		assetId = uploaded
		spec.version += 1
		spec.upload = { modelAssetId = uploaded, sourceSha256 = sha, uploadedAt = os.date("!%Y-%m-%dT%H:%M:%SZ") }
		fs.writeFile(Paths.specFile(rootDir, artPath), AssetSpec.encode(spec))
	end
	local bytes, code, detail = OpenCloud.download(deps, session, assetId)
	if bytes == nil then
		die(string.format("%s %s", code :: string, detail or ""))
	end
	fs.writeDir(buildDir)
	fs.writeFile(buildDir .. "/raw.rbxm", bytes)
	print(string.format("[ART] uploaded %s asset %s", artPath, assetId))
	return assetId
end

-- Returns the detected yaw and scale.
local function normalizeArt(rootDir: string, artPath: string, rawFile: string?): (number, number)
	local spec = loadSpec(rootDir, artPath)
	local buildDir = Paths.buildDir(rootDir, artPath)
	local rawPath = rawFile or (buildDir .. "/raw.rbxm")
	if not fs.isFile(rawPath) then
		die("ART_NO_RAW: " .. rawPath)
	end
	local reportPath = buildDir .. "/report.json"
	if not fs.isFile(reportPath) then
		die("ART_NO_REPORT: run export first (" .. reportPath .. ")")
	end
	local reportOk, report = pcall(serde.decode, "json", fs.readFile(reportPath))
	if not reportOk or type(report) ~= "table" or report.schemaVersion ~= 1 then
		die("ART_BAD_REPORT: " .. reportPath)
	end
	local rawOk, raw = pcall(roblox.deserializeModel, fs.readFile(rawPath))
	if not rawOk then
		die("ART_BAD_RAW: " .. rawPath)
	end
	local model, code, detail, info = Normalize.normalize(raw, report, spec, ArtPalette, Config.IMPORT_YAW_DEGREES)
	if model == nil then
		die(string.format("%s %s", code :: string, detail or ""))
	end
	local output = Paths.rbxmFile(rootDir, artPath)
	fs.writeDir(Paths.parentDir(output))
	fs.writeFile(output, roblox.serializeModel({ model }))
	print(string.format("[ART] normalized %s yaw %d scale %.4f", artPath, info.yaw, info.scale))
	return info.yaw, info.scale
end

local function buildArt(rootDir: string, artPath: string): (number, number, string)
	exportArt(rootDir, artPath)
	local assetId = uploadArt(rootDir, artPath, false)
	local yaw, scale = normalizeArt(rootDir, artPath, nil)
	return yaw, scale, assetId
end

local function verifyPlace(placeFile: string?)
	if placeFile == nil or not fs.isFile(placeFile) then
		die("ART_NO_PLACE: " .. tostring(placeFile))
	end
	local ok, place = pcall(roblox.deserializePlace, fs.readFile(placeFile :: string))
	if not ok then
		die("ART_BAD_PLACE: " .. tostring(placeFile))
	end
	local specPaths = listSpecs(root)
	local rbxmPaths = listRbxm(root)
	local hasRbxm: { [string]: boolean } = {}
	for _, artPath in ipairs(rbxmPaths) do
		hasRbxm[artPath] = true
	end
	local entries = {}
	local failures = {}
	for _, artPath in ipairs(specPaths) do
		local data = nil
		local decoded, value = pcall(serde.decode, "json", fs.readFile(Paths.specFile(root, artPath)))
		if decoded then
			data = value
		end
		local spec, problem = AssetSpec.validate(data, artPath)
		if spec == nil then
			table.insert(failures, { artPath = artPath, code = "ART_BAD_SPEC", detail = (problem :: string):sub(14) })
		else
			table.insert(entries, { artPath = artPath, spec = spec, hasRbxm = hasRbxm[artPath] == true })
		end
	end
	for _, failure in ipairs(Verify.verifyPlace(place, entries)) do
		table.insert(failures, failure)
	end
	local fileFailures, pending = Verify.verifyFiles(rbxmPaths, specPaths)
	for _, failure in ipairs(fileFailures) do
		table.insert(failures, failure)
	end
	local failed: { [string]: boolean } = {}
	for _, failure in ipairs(failures) do
		failed[failure.artPath] = true
		print(string.format("[ART] FAIL %s %s %s", failure.artPath, failure.code, failure.detail or ""))
	end
	local integrated = 0
	for _, entry in ipairs(entries) do
		if entry.hasRbxm and not failed[entry.artPath] then
			integrated += 1
		end
	end
	print(string.format("[ART] %d integrated, %d pending, %d failed", integrated, #pending, #failures))
	process.exit(if #failures > 0 then 1 else 0)
end

local function probe()
	local blender = requireBlender()
	local result = Blender.run(blender, nil, PROBE_SCRIPT, { "--out", Paths.blendFile(PROBE_ROOT, PROBE_PATH) })
	if result.code ~= 0 then
		showBlenderFailure("PROBE", result)
	end
	local yaw, scale, assetId = buildArt(PROBE_ROOT, PROBE_PATH)
	print(string.format("[ART] probe OK yaw %d scale %.4f asset %s", yaw, scale, assetId))
end

if command == "doctor" then
	doctor()
elseif command == "export" then
	exportArt(root, requireArtPath())
elseif command == "render" then
	renderArt(root, requireArtPath())
elseif command == "upload" then
	uploadArt(root, requireArtPath(), options["--force"] == true)
elseif command == "normalize" then
	normalizeArt(root, requireArtPath(), if type(options["--raw"]) == "string" then options["--raw"] :: string else nil)
elseif command == "build" then
	buildArt(root, requireArtPath())
elseif command == "verify" then
	verifyPlace(positional[2])
elseif command == "probe" then
	probe()
else
	die(
		"usage: lune run tools/art/art.luau doctor|export|render|upload|normalize|build|verify|probe [args] [--root <dir>]"
	)
end
