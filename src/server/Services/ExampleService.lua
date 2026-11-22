--!strict
-- Example service: pure logic in functions, Roblox side effects only in start().
-- Replace or delete it when the first real service exists.
local ExampleService = {}

function ExampleService.add(a: number, b: number): number
	return a + b
end

function ExampleService.start()
	-- Connect events, start loops, create remotes here.
end

return ExampleService
