-- Example unit test case. Runs headless (`lune run tests/headless/run.luau`) and in Studio.
return function(t)
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local ExampleService = require(Services.ExampleService)
	local expect = t.expect

	t.test("adds two numbers", function()
		expect.equal(ExampleService.add(2, 3), 5)
	end)
end
