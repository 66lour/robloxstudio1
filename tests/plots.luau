-- PlotService: plot assignment detection and the own-tycoon safe zone, using
-- mock players and a fake tycoon map.
-- Run from the repo root with Lune: lune run tests/plots
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("./harness")

local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3

-- A fake Workspace: Tycoons/Plot1..3 plus a team-named plot.
local workspace = Instance.new("Folder")
workspace.Name = "Workspace"
local tycoons = Instance.new("Folder")
tycoons.Name = "Tycoons"
tycoons.Parent = workspace

local function makePlot(name: string, center, withSafeZone: boolean)
	local plot = Instance.new("Model")
	plot.Name = name
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(60, 1, 60)
	floor.CFrame = CFrame.new(center)
	floor.Parent = plot
	local wall = Instance.new("Part")
	wall.Size = Vector3.new(2, 20, 60)
	wall.CFrame = CFrame.new(center + Vector3.new(29, 10, 0))
	wall.Parent = plot
	if withSafeZone then
		local zone = Instance.new("Part")
		zone.Name = "SafeZone"
		zone.Size = Vector3.new(30, 1, 30)
		zone.CFrame = CFrame.new(center)
		zone.Parent = plot
	end
	plot.Parent = tycoons
	return plot
end

local plot1 = makePlot("Plot1", Vector3.new(0, 0, 0), true)
local plot2 = makePlot("Plot2", Vector3.new(200, 0, 0), false)
plot2:SetAttribute("OwnerId", 202)
local plot3 = makePlot("Plot3", Vector3.new(400, 0, 0), false)
plot3:SetAttribute("PlotId", 3)
local redPlot = makePlot("Red Tycoon", Vector3.new(600, 0, 0), false)

-- Mock players.
local players = {}
local function makePlayer(userId: number, name: string, attributes: { [string]: any }?, team: any?)
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100 -- Lune has no default for it
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local children = Instance.new("Folder")
	local player = {
		UserId = userId,
		Name = name,
		Team = team,
		Neutral = team == nil,
		Character = character,
		Root = root,
		Humanoid = humanoid,
		_attributes = attributes or {},
		_children = children,
	}
	function player.GetAttribute(self, key)
		return self._attributes[key]
	end
	function player.SetAttribute(self, key, value)
		self._attributes[key] = value
	end
	function player.FindFirstChild(self, key)
		return self._children:FindFirstChild(key)
	end
	table.insert(players, player)
	return player
end

local signal = { Connect = function() end }
Harness.setGlobals({
	game = {
		GetService = function(_, name)
			if name == "Players" then
				return {
					PlayerRemoving = signal,
					GetPlayers = function()
						return players
					end,
					GetPlayerFromCharacter = function(_, character)
						for _, p in players do
							if p.Character == character then
								return p
							end
						end
						return nil
					end,
				}
			elseif name == "RunService" then
				return { IsStudio = function() return false end }
			elseif name == "Workspace" then
				return workspace
			end
			error("unexpected service " .. name)
		end,
	},
	print = function() end,
	warn = function() end,
})

local PlotService = Harness.require(Harness.server().Services.PlotService)
PlotService.Config.AssignmentCacheTime = 0
PlotService.Config.BoundsCacheTime = 0

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

local function place(player, position)
	player.Root.CFrame = CFrame.new(position)
end

-- 1. Attribute "Plot" naming a plot model.
local alice = makePlayer(101, "Alice", { Plot = "Plot1" })
local assigned, plot = PlotService.GetAssignment(alice)
check(assigned and plot ~= nil and plot.Name == "Plot1", "Plot attribute should assign Plot1")

-- 2. "Not Assigned" and friends mean guest.
for _, value in { "Not Assigned", "none", "", false, 0 } do
	local guest = makePlayer(900, "Guest", { Plot = value })
	check(not PlotService.IsAssigned(guest), `Plot = {tostring(value)} should be a guest`)
end

-- 3. Owner marker on the plot (UserId attribute).
local bob = makePlayer(202, "Bob")
assigned, plot = PlotService.GetAssignment(bob)
check(assigned and plot ~= nil and plot.Name == "Plot2", "OwnerId attribute should assign Plot2")

-- 4. Numeric plot id matched through the plot's PlotId attribute.
local cara = makePlayer(303, "Cara", { PlotId = 3 })
assigned, plot = PlotService.GetAssignment(cara)
check(assigned and plot ~= nil and plot.Name == "Plot3", "PlotId attribute should match plot's PlotId")

-- 5. Owner as a StringValue named "Owner".
local ownerValue = Instance.new("StringValue")
ownerValue.Name = "Owner"
ownerValue.Value = "Dan"
ownerValue.Parent = plot1
local dan = makePlayer(404, "Dan")
check(PlotService.IsAssigned(dan), "Owner StringValue with the player's name should assign")
ownerValue:Destroy()

-- 6. Teams: guest team vs a team with a plot named after it.
local hired = makePlayer(505, "Eve", nil, { Name = "For Hire", TeamColor = "White" })
check(not PlotService.IsAssigned(hired), "For Hire team should be a guest")
local red = makePlayer(606, "Finn", nil, { Name = "Red Tycoon", TeamColor = "Bright red" })
assigned, plot = PlotService.GetAssignment(red)
check(assigned and plot ~= nil and plot.Name == "Red Tycoon", "a team with a plot named after it should be assigned")

-- 7. Nobody else is assigned.
local stranger = makePlayer(707, "Gus")
check(not PlotService.IsAssigned(stranger), "players without any marker are guests")

-- 8. Safe zone: SafeZone part (Plot1), whole-plot bounds (Plot2).
place(alice, Vector3.new(5, 3, 5))
check(PlotService.IsInOwnSafeZone(alice), "standing on own SafeZone should be safe")
place(alice, Vector3.new(5, 70, 5))
check(PlotService.IsInOwnSafeZone(alice), "the safe zone extends upward")
place(alice, Vector3.new(25, 3, 25))
check(not PlotService.IsInOwnSafeZone(alice), "outside the SafeZone part (but on the plot) is not safe for Plot1")
place(alice, Vector3.new(200, 3, 0))
check(not PlotService.IsInOwnSafeZone(alice), "someone else's plot is not a safe zone")
place(bob, Vector3.new(210, 3, 10))
check(PlotService.IsInOwnSafeZone(bob), "without a SafeZone part the whole plot is safe")
place(bob, Vector3.new(300, 3, 0))
check(not PlotService.IsInOwnSafeZone(bob), "outside own plot is not safe")

-- 9. CanBeTargeted combines all of it.
place(alice, Vector3.new(100, 3, 100))
check(PlotService.CanBeTargeted(alice), "assigned player in the open is a target")
place(alice, Vector3.new(0, 3, 0))
check(not PlotService.CanBeTargeted(alice), "player inside own tycoon is not a target")
place(stranger, Vector3.new(100, 3, 100))
check(not PlotService.CanBeTargeted(stranger), "guests are never targets")
place(bob, Vector3.new(100, 3, 100))
bob.Humanoid.Health = 0
check(not PlotService.CanBeTargeted(bob), "dead players are not targets")

print("")
if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("All plot checks passed")
