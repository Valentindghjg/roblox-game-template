--!strict
-- Server bootstrap: requires every service in Services and starts the ones with a start function.
local Services = script.Parent:WaitForChild("Services")

for _, module in ipairs(Services:GetChildren()) do
	if module:IsA("ModuleScript") then
		local service = require(module) :: any
		if type(service) == "table" and type(service.start) == "function" then
			service.start()
		end
	end
end

print("[Game] server started")
