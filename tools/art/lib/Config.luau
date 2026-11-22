--!strict
-- Constants of the art pipeline. The endpoints follow the Open Cloud reference
-- as known at planning; the first real `probe` run verifies them (once the Open Cloud key exists).
local Config = {
	ASSETS_URL = "https://apis.roblox.com/assets/v1/assets",
	OPERATIONS_URL = "https://apis.roblox.com/assets/v1/operations/",
	DELIVERY_URL = "https://apis.roblox.com/asset-delivery-api/v1/assetId/",
	POLL_SECONDS = 2,
	MAX_POLLS = 60,
	RATE_LIMIT_WAIT = 10,
	MAX_RATE_RETRIES = 3,
	DOWNLOAD_RETRIES = 5,
	DOWNLOAD_WAIT = 5,
	-- Set to the yaw the probe detects when it is not 0 (see docs/plans/art pipeline.md).
	IMPORT_YAW_DEGREES = 0,
	MATCH_ABS = 0.02,
	MATCH_REL = 0.01,
	ART_ROOT_SIZE = 0.05,
	-- Budgets per tier: { triangles, meshParts } (PROVISIONAL, engineering).
	BUDGET = {
		A = { 4000, 10 },
		B = { 1000, 4 },
	},
	DEFAULT_BLENDER = "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe",
}

return Config
