-- The art palette is valid: every key has an RGB triple in 0..255 and a material name.
return function(t)
	local ArtPalette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ArtPalette"))
	local expect = t.expect

	t.test("every palette entry has rgb and material", function()
		local count = 0
		for key, entry in pairs(ArtPalette) do
			count += 1
			expect.equal(type(key), "string")
			expect.equal(#entry.rgb, 3)
			for _, channel in ipairs(entry.rgb) do
				expect.truthy(channel >= 0 and channel <= 255)
			end
			expect.equal(type(entry.material), "string")
		end
		expect.truthy(count > 0)
	end)
end
