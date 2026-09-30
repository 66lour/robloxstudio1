-- Builds every weapon's built-in Tool outside Roblox and checks it.
-- Run from the repo root with Lune: lune run tests/weapons
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("./harness")

Harness.setGlobals({
	game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return { Shared = Harness.shared() }
			end
			error("unexpected service " .. name)
		end,
	},
})

local WeaponCatalog = Harness.require(Harness.shared().Config.WeaponCatalog)
local WeaponModels = Harness.require(Harness.server().Weapons.WeaponModels)

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

for _, def in WeaponCatalog.List do
	local ok, tool = pcall(WeaponModels.Build, def)
	check(ok, `{def.Id} failed to build: {tool}`)
	if not ok then
		continue
	end
	check(tool:IsA("Tool") and tool.Name == def.Name, `{def.Id} should be a Tool named {def.Name}`)
	local handle = tool:FindFirstChild("Handle")
	check(handle ~= nil and handle:IsA("BasePart"), `{def.Id} needs a Handle`)
	-- The Grip points the Handle's +Z (the blade) straight up.
	check((tool.Grip.UpVector - roblox.Vector3.new(0, 0, 1)).Magnitude < 1e-4, `{def.Id} grip should point the blade up`)

	local parts, maxZ, trails = 0, 0, 0
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			check(d.Massless and not d.CanCollide and not d.CanTouch, `{def.Id} part {d.Name} must be massless, non-colliding and non-touching`)
			if d.Name ~= "Handle" then
				local weld = d:FindFirstChildOfClass("WeldConstraint")
				check(weld ~= nil and weld.Part0 ~= nil and weld.Part0.Name == "Handle", `{def.Id} part {d.Name} must be welded to the Handle`)
			end
			maxZ = math.max(maxZ, d.CFrame.Position.Z + d.Size.Z / 2)
		elseif d:IsA("Trail") then
			trails += 1
			check(not d.Enabled, `{def.Id} swing trail should start disabled`)
		end
	end
	check(trails == 1, `{def.Id} should have one swing trail`)
	check(maxZ > 2, `{def.Id} blade should extend along +Z`)
	print(string.format("%-24s %4d dmg  %2d parts  reach %.1f studs", def.Name, def.Damage, parts, maxZ))
end

print("")
if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("All weapon checks passed")
