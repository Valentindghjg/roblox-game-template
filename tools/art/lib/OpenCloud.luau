--!nonstrict
-- Open Cloud Assets upload and Asset Delivery download for the art pipeline.
-- HTTP and sleeping are injected as deps = { request, sleep } so tests can fake them.
--   request({ url, method, headers, body }) -> { status, body, headers } or nil, message
--   sleep(seconds)
-- Every function returns a result, or nil plus a code and a detail. The API key goes only
-- into request headers; it is scrubbed from every returned detail.
local serde = require("@lune/serde")
local Config = require("./Config")

local OpenCloud = {}

export type Session = { apiKey: string, creator: { userId: string?, groupId: string? } }

local MAX_BODY_DETAIL = 200

local function clip(session: Session, body: any): string
	local text = tostring(body or "")
	if session.apiKey ~= "" then
		local escaped = string.gsub(session.apiKey, "%p", "%%%0")
		text = string.gsub(text, escaped, "***")
	end
	if #text > MAX_BODY_DETAIL then
		text = string.sub(text, 1, MAX_BODY_DETAIL)
	end
	return text
end

local function header(response: any, name: string): string?
	for key, value in pairs(response.headers or {}) do
		if string.lower(key) == name then
			return value
		end
	end
	return nil
end

local function decode(text: string): any
	local ok, value = pcall(serde.decode, "json", text)
	return if ok and type(value) == "table" then value else nil
end

local function randomHex(length: number): string
	local digits = {}
	for index = 1, length do
		digits[index] = string.format("%x", math.random(0, 15))
	end
	return table.concat(digits)
end

local function multipart(boundary: string, requestJson: string, fbx: string): string
	return table.concat({
		"--" .. boundary,
		'Content-Disposition: form-data; name="request"',
		"Content-Type: application/json",
		"",
		requestJson,
		"--" .. boundary,
		'Content-Disposition: form-data; name="fileContent"; filename="model.fbx"',
		"Content-Type: model/fbx",
		"",
		fbx,
		"--" .. boundary .. "--",
		"",
	}, "\r\n")
end

local function assetIdText(value: any): string?
	if type(value) == "number" then
		return string.format("%.0f", value)
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

-- POST the FBX, then poll the operation until the model asset id is known.
function OpenCloud.upload(
	deps: any,
	session: Session,
	artPath: string,
	displayName: string,
	fbx: string
): (string?, string?, string?)
	local boundary = "gameart" .. randomHex(16)
	local requestJson = serde.encode("json", {
		assetType = "Model",
		displayName = displayName,
		description = "the game art: " .. artPath,
		creationContext = { creator = session.creator },
	})
	local retries = 0
	local response
	while true do
		local transportError
		response, transportError = deps.request({
			url = Config.ASSETS_URL,
			method = "POST",
			headers = {
				["x-api-key"] = session.apiKey,
				["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
			},
			body = multipart(boundary, requestJson, fbx),
		})
		if response == nil then
			-- The upload may have reached Roblox: never retry, check the Creator Dashboard.
			return nil, "ART_UPLOAD_AMBIGUOUS", clip(session, transportError)
		end
		if response.status == 429 and retries < Config.MAX_RATE_RETRIES then
			retries += 1
			deps.sleep(tonumber(header(response, "retry-after")) or Config.RATE_LIMIT_WAIT)
		else
			break
		end
	end
	if response.status ~= 200 then
		return nil, "ART_UPLOAD_FAILED", string.format("%s %s", tostring(response.status), clip(session, response.body))
	end

	local operation = decode(response.body)
	if operation == nil then
		return nil, "ART_UPLOAD_FAILED", "200 " .. clip(session, response.body)
	end
	local operationId = operation.operationId or string.match(tostring(operation.path or ""), "operations/(.+)$")
	for _ = 1, Config.MAX_POLLS do
		if operation.done == true then
			if operation.error ~= nil then
				return nil, "ART_UPLOAD_FAILED", clip(session, serde.encode("json", operation.error))
			end
			local assetId = assetIdText(operation.response and operation.response.assetId)
			if assetId == nil then
				return nil, "ART_UPLOAD_FAILED", "operation finished without an assetId"
			end
			return assetId, nil, nil
		end
		if operationId == nil then
			return nil, "ART_UPLOAD_FAILED", "no operation id in the upload response"
		end
		deps.sleep(Config.POLL_SECONDS)
		local poll = deps.request({
			url = Config.OPERATIONS_URL .. operationId,
			method = "GET",
			headers = { ["x-api-key"] = session.apiKey },
		})
		if poll ~= nil then
			if poll.status ~= 200 then
				return nil, "ART_UPLOAD_FAILED", string.format("%s %s", tostring(poll.status), clip(session, poll.body))
			end
			operation = decode(poll.body) or { done = false }
		end
	end
	return nil,
		"ART_UPLOAD_TIMEOUT",
		string.format("operation %s not done after %d polls", tostring(operationId), Config.MAX_POLLS)
end

-- Delivery API: the JSON answer names a CDN location that holds the processed model bytes.
function OpenCloud.download(deps: any, session: Session, assetId: string): (string?, string?, string?)
	local lastStatus = "no response"
	for attempt = 1, Config.DOWNLOAD_RETRIES do
		local delivery = deps.request({
			url = Config.DELIVERY_URL .. assetId,
			method = "GET",
			headers = { ["x-api-key"] = session.apiKey },
		})
		if delivery ~= nil then
			lastStatus = tostring(delivery.status)
			local location = delivery.status == 200 and decode(delivery.body)
			if location and type(location.location) == "string" then
				local file = deps.request({ url = location.location, method = "GET", headers = {} })
				if file ~= nil then
					lastStatus = tostring(file.status)
					if file.status == 200 then
						return file.body, nil, nil
					end
				end
			end
		end
		if attempt < Config.DOWNLOAD_RETRIES then
			deps.sleep(Config.DOWNLOAD_WAIT)
		end
	end
	return nil, "ART_DOWNLOAD_FAILED", string.format("asset %s, last status %s", assetId, lastStatus)
end

-- "user:123" or "group:456" -> the creator table of the upload request.
function OpenCloud.parseCreator(text: string?): { userId: string?, groupId: string? }?
	local kind, id = string.match(text or "", "^(%l+):(%d+)$")
	if kind == "user" then
		return { userId = id }
	elseif kind == "group" then
		return { groupId = id }
	end
	return nil
end

return OpenCloud
