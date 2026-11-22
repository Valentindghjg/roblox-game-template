--!strict
-- Runs headless Blender for the art pipeline.
local fs = require("@lune/fs")
local process = require("@lune/process")
local Config = require("./Config")

local Blender = {}

export type Result = { ok: boolean, code: number, stdout: string, stderr: string }

Blender.MISSING_CODE = "ART_BLENDER_MISSING"
Blender.MISSING_HINT = "winget install BlenderFoundation.Blender"

-- GAME_BLENDER overrides the default install path. Returns nil when no executable exists.
function Blender.resolve(): string?
	local override = process.env.GAME_BLENDER
	local path = if override ~= nil and override ~= "" then override else Config.DEFAULT_BLENDER
	if fs.isFile(path) then
		return path
	end
	return nil
end

-- blender -b --factory-startup [<blend>] --python <script> -- <extra...>
function Blender.arguments(blend: string?, script: string, extra: { string }): { string }
	local args = { "-b", "--factory-startup" }
	if blend ~= nil then
		table.insert(args, blend)
	end
	table.insert(args, "--python")
	table.insert(args, script)
	table.insert(args, "--")
	for _, value in ipairs(extra) do
		table.insert(args, value)
	end
	return args
end

function Blender.run(blender: string, blend: string?, script: string, extra: { string }): Result
	local result = process.exec(blender, Blender.arguments(blend, script, extra))
	return { ok = result.ok, code = result.code, stdout = result.stdout, stderr = result.stderr }
end

-- The first line of `blender --version`, for example "Blender 5.2.2 LTS".
function Blender.version(blender: string): string?
	local ok, result = pcall(process.exec, blender, { "--version" })
	if not ok or not result.ok then
		return nil
	end
	return string.match(result.stdout, "^([^\r\n]+)")
end

-- The ART_* status lines a Blender script printed (errors carry their code first).
function Blender.artLines(result: Result): { string }
	local lines = {}
	for line in string.gmatch(result.stdout .. "\n" .. result.stderr, "[^\r\n]+") do
		if string.sub(line, 1, 4) == "ART_" then
			table.insert(lines, line)
		end
	end
	return lines
end

return Blender
