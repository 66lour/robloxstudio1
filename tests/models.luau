-- Builds every boss model outside Roblox and checks the rig.
-- Run from the repo root with Lune: lune run tests/models
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("./harness")

local CFrame = roblox.CFrame

Harness.setGlobals({
	game = {
		GetService = function(_, name)
			if name == "MaterialService" then
				return { FindFirstChild = function() return nil end }
			end
			error("unexpected service " .. name)
		end,
	},
})

local shared = Harness.shared()
local server = Harness.server()
local BossRoster = Harness.require(shared.Config.BossRoster)
local Rarities = Harness.require(shared.Config.Rarities)
local ModelKit = Harness.require(server.Bosses.Models.ModelKit)

local MAX_PARTS = 260
local MAX_LIGHTS = 4

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

local function near(a, b, epsilon)
	return (a - b).Magnitude < (epsilon or 1e-3)
end

local function rotationNear(a, b)
	return near(a.RightVector, b.RightVector, 1e-3) and near(a.UpVector, b.UpVector, 1e-3) and near(a.LookVector, b.LookVector, 1e-3)
end

-- Every roster boss has a design, and every design belongs to a boss.
local designFiles = {}
for _, entry in fs.readDir("src/server/Bosses/Models/Designs") do
	designFiles[(string.gsub(entry, "%.luau$", ""))] = true
end
for _, def in BossRoster.List do
	check(designFiles[def.Id] == true, `{def.Id} has no design module`)
	designFiles[def.Id] = nil
end
for extra in designFiles do
	check(false, `design {extra} has no boss in BossRoster`)
end

local heights = {}

for _, def in BossRoster.List do
	local stats = BossRoster.GetStats(def)
	local kit = ModelKit.new(def, stats.Scale)
	local ok, err = pcall(function()
		Harness.require(server.Bosses.Models.Designs[def.Id])(kit, def)
	end)
	check(ok, `{def.Id} design errored: {err}`)
	if not ok then
		continue
	end
	local model = kit:Finish()
	local root = model.PrimaryPart
	check(root ~= nil and root.Name == "HumanoidRootPart", `{def.Id} PrimaryPart must be the HumanoidRootPart`)
	check(root.CanCollide and not root.Massless, `{def.Id} root must collide and have mass`)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	check(humanoid ~= nil and humanoid.HipHeight > 0, `{def.Id} needs a Humanoid with HipHeight`)
	check(model:GetAttribute("AnimStyle") == def.AnimStyle, `{def.Id} AnimStyle attribute`)
	check(model:GetAttribute("ProceduralRig") == true, `{def.Id} ProceduralRig attribute`)
	check(math.abs(model:GetAttribute("BossScale") - stats.Scale) < 1e-6, `{def.Id} BossScale attribute`)

	-- Lune hands out a new wrapper for every Instance reference, so parts are
	-- keyed by an id attribute rather than by the Instance itself.
	local nextId = 0
	local byId = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			nextId += 1
			d:SetAttribute("_id", nextId)
			byId[nextId] = d
		end
	end
	local function id(part)
		return part and part:GetAttribute("_id")
	end

	-- How each part is attached.
	local parentOf = {}
	local joints = {}
	local attachments = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
			check(d.Part1 ~= nil and d.Part0 ~= nil, `{def.Id} joint {d.Name} is missing a part`)
			attachments[id(d.Part1)] = (attachments[id(d.Part1)] or 0) + 1
			parentOf[id(d.Part1)] = id(d.Part0)
			-- Rest pose is consistent and the joint frame is aligned with the root.
			local a = d.Part0.CFrame * d.C0
			local b = d.Part1.CFrame * d.C1
			check(near(a.Position, b.Position) and rotationNear(a, b), `{def.Id} joint {d.Name} rest pose mismatch`)
			check(rotationNear(a, CFrame.identity), `{def.Id} joint {d.Name} frame is not root-aligned`)
		elseif d:IsA("WeldConstraint") then
			check(d.Part0 ~= nil and d.Part1 ~= nil, `{def.Id} weld is missing a part`)
			attachments[id(d.Part1)] = (attachments[id(d.Part1)] or 0) + 1
			parentOf[id(d.Part1)] = id(d.Part0)
		end
	end

	local parts, lights, maxY = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if id(d) ~= id(root) then
				check(attachments[id(d)] == 1, `{def.Id} part {d.Name} is attached {attachments[id(d)] or 0} times`)
				check(d.Massless and not d.CanCollide, `{def.Id} part {d.Name} must be massless and non-colliding`)
				-- Walk up to the root.
				local current, steps = id(d), 0
				while current ~= id(root) and current and steps < 64 do
					current = parentOf[current]
					steps += 1
				end
				check(current == id(root), `{def.Id} part {d.Name} is not connected to the root`)
			end
			if d.Transparency < 0.95 and not string.find(d.Name, "Orbit") then
				local cf, half = d.CFrame, d.Size / 2
				local extent = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
				maxY = math.max(maxY, cf.Position.Y + extent)
			end
		elseif d:IsA("PointLight") then
			lights += 1
		end
	end
	check(parts <= MAX_PARTS, `{def.Id} has {parts} parts (max {MAX_PARTS})`)
	check(lights <= MAX_LIGHTS, `{def.Id} has {lights} lights (max {MAX_LIGHTS})`)

	for _, name in { "Root", "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow" } do
		check(joints[name] ~= nil, `{def.Id} is missing joint {name}`)
	end
	if kit.Segments.LeftThigh then
		for _, name in { "LeftHip", "RightHip", "LeftKnee", "RightKnee" } do
			check(joints[name] ~= nil, `{def.Id} is missing joint {name}`)
		end
	end

	heights[def.Id] = maxY
	print(string.format("%-20s %-9s scale %.2f  height %5.1f studs  parts %3d  lights %d  joints %d", def.Id, def.Rarity, stats.Scale, maxY, parts, lights, #(function()
		local list = {}
		for name in joints do
			table.insert(list, name)
		end
		return list
	end)()))
end

-- Rarer bosses are visibly bigger: every boss towers over the tier below.
local previousMax, previousTier = 0, ""
for _, rarityName in Rarities.Order do
	local tierMin, tierMax = math.huge, 0
	for _, def in BossRoster.ByRarity[rarityName] do
		if heights[def.Id] then
			tierMin = math.min(tierMin, heights[def.Id])
			tierMax = math.max(tierMax, heights[def.Id])
		end
	end
	check(tierMin > previousMax, `shortest {rarityName} boss ({tierMin}) must be taller than the tallest {previousTier} boss ({previousMax})`)
	previousMax, previousTier = tierMax, rarityName
end

print("")
if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("All model checks passed")
