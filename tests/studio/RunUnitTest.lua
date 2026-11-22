--!strict
-- Discovers and runs unit test cases below ServerStorage.UnitTest.Cases.
local ServerStorage = game:GetService("ServerStorage")

local function format(value: unknown): string
	return type(value) == "string" and string.format("%q", value) or tostring(value)
end

local expect = {}
function expect.equal(actual: unknown, expected: unknown)
	if actual ~= expected then
		error(string.format("expected %s, got %s", format(expected), format(actual)), 2)
	end
end
function expect.truthy(value: unknown)
	if not value then
		error(string.format("expected truthy, got %s", format(value)), 2)
	end
end
function expect.falsy(value: unknown)
	if value then
		error(string.format("expected falsy, got %s", format(value)), 2)
	end
end
function expect.throws(fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		error("expected function to throw", 2)
	end
	return err
end

return function(filter: string?, timeout: number?)
	local cases = ServerStorage:WaitForChild("UnitTest"):WaitForChild("Cases")
	local limit = timeout or 5
	local totals = { run = 0, passed = 0, failed = 0 }
	for _, module in ipairs(cases:GetDescendants()) do
		if module:IsA("ModuleScript") and (filter == nil or string.find(module.Name, filter, 1, true)) then
			local loaded, factory = pcall(require, module)
			if not loaded or type(factory) ~= "function" then
				totals.run += 1
				totals.failed += 1
				warn(string.format("[FAIL] %s could not load: %s", module.Name, tostring(factory)))
			else
				local context = { expect = expect }
				function context.test(name: string, fn: () -> ())
					totals.run += 1
					local done, passed, message = false, false, nil
					task.spawn(function()
						passed, message = pcall(fn)
						done = true
					end)
					local elapsed = 0
					while not done and elapsed < limit do
						elapsed += task.wait()
					end
					if not done then
						totals.failed += 1
						warn(string.format("[TIMEOUT] %s > %s", module.Name, name))
					elseif passed then
						totals.passed += 1
						print(string.format("[PASS] %s > %s", module.Name, name))
					else
						totals.failed += 1
						warn(string.format("[FAIL] %s > %s | %s", module.Name, name, tostring(message)))
					end
				end
				local built, buildError = pcall(factory, context)
				if not built then
					totals.run += 1
					totals.failed += 1
					warn(string.format("[FAIL] %s setup | %s", module.Name, tostring(buildError)))
				end
			end
		end
	end
	print(string.format("[SUMMARY] %d run, %d passed, %d failed", totals.run, totals.passed, totals.failed))
	return totals
end
