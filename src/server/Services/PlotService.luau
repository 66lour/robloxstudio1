--!strict
-- Tells the boss system which players own a tycoon plot and whether they are
-- standing inside it.
--
-- Plot-only aggro rules:
--   * Players assigned to a plot can be targeted and damaged by bosses.
--   * Guests ("Not Assigned", no plot) are ignored completely and can't be hurt
--     by bosses.
--   * Players standing inside their own tycoon (their safe zone) are ignored
--     too.
--
-- The tycoon system isn't part of this repository, so this module recognizes
-- the common ways tycoon kits mark ownership. Checked in order:
--   1. A player attribute or value object from CONFIG.PlayerKeys, e.g.
--      player:SetAttribute("Plot", "Plot3"), or an ObjectValue Player.Plot
--      pointing at the plot model. Values in CONFIG.GuestValues ("Not
--      Assigned", "None", "", 0, false…) mean no plot.
--   2. An owner marker on a plot model inside a CONFIG.PlotFolders folder: an
--      ObjectValue "Owner" (Value = Player), or an "Owner"/"OwnerId"/
--      "OwnerUserId" attribute or value holding the UserId or name. This covers
--      Zednov's Tycoon Kit and most custom tycoons.
--   3. Teams: a team from CONFIG.GuestTeams ("Not Assigned", "For Hire"…)
--      means guest; any other team counts if a plot is named after it or has
--      a matching "TeamColor"/"Team" value (team-based tycoon kits).
-- If none of these apply, the player is a guest.
--
-- Safe zone: BaseParts named like CONFIG.SafeZoneNames inside the player's
-- plot, or the plot's whole bounding box if it has none, extended
-- CONFIG.SafeZoneHeight studs upwards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	PlayerKeys = { "Plot", "PlotId", "PlotName", "Tycoon", "TycoonId", "AssignedPlot" },
	GuestValues = { "not assigned", "unassigned", "none", "guest", "nil", "n/a", "" },
	-- Folders (paths from Workspace, "/"-separated) whose children are plots.
	PlotFolders = { "Tycoons", "Plots", "TycoonPlots", "PlayerPlots", "Zednov's Tycoon Kit/Tycoons" },
	OwnerKeys = { "Owner", "OwnerId", "OwnerUserId", "OwnerName" },
	-- Attributes/values on a plot that hold its id, for matching a player's
	-- "Plot" value to the plot model (the plot's Name is always tried too).
	PlotIdKeys = { "PlotId", "Id", "PlotName", "Number" },
	GuestTeams = { "Not Assigned", "For Hire", "Neutral", "Guests", "Guest", "Lobby", "Unassigned" },
	-- Plot keys that link a plot to a team.
	TeamKeys = { "TeamColor", "Team" },
	SafeZoneNames = { "SafeZone", "SafeArea", "Boundary", "PlotBoundary", "PlotArea" },
	SafeZoneHeight = 80,
	SafeZonePadding = 2,
	AssignmentCacheTime = 0.5,
	BoundsCacheTime = 5,
}

type Box = { CFrame: CFrame, Size: Vector3 }

local PlotService = {}
PlotService.Config = CONFIG

local assignmentCache: { [Player]: { Time: number, Assigned: boolean, Plot: Instance? } } = {}
local boundsCache: { [Instance]: { Time: number, Boxes: { Box } } } = {}

local function lower(value: string): string
	return string.lower((string.gsub(value, "^%s+", ""):gsub("%s+$", "")))
end

local function isGuestString(value: string): boolean
	return table.find(CONFIG.GuestValues, lower(value)) ~= nil
end

local function getPlotFolders(): { Instance }
	local folders = {}
	for _, path in CONFIG.PlotFolders do
		local current: Instance? = Workspace
		for segment in string.gmatch(path, "[^/]+") do
			current = if current then current:FindFirstChild(segment) else nil
		end
		if current then
			table.insert(folders, current)
		end
	end
	return folders
end

local function readKey(instance: Instance, key: string): any
	local attribute = instance:GetAttribute(key)
	if attribute ~= nil then
		return attribute
	end
	local child = instance:FindFirstChild(key)
	if child and child:IsA("ValueBase") then
		local value = (child :: any).Value
		if value == nil then
			-- An empty ObjectValue is an explicit "no plot".
			return false
		end
		return value
	end
	return nil
end

-- Finds the plot model that a player's "Plot" value refers to.
local function resolvePlot(reference: any): Instance?
	if typeof(reference) == "Instance" then
		return reference
	end
	if type(reference) ~= "string" and type(reference) ~= "number" then
		return nil
	end
	local wanted = tostring(reference)
	for _, folder in getPlotFolders() do
		for _, plot in folder:GetChildren() do
			if plot.Name == wanted then
				return plot
			end
			for _, key in CONFIG.PlotIdKeys do
				local id = readKey(plot, key)
				if id ~= nil and tostring(id) == wanted then
					return plot
				end
			end
		end
	end
	return nil
end

local function ownsPlot(plot: Instance, player: Player): boolean
	for _, key in CONFIG.OwnerKeys do
		local owner = readKey(plot, key)
		if owner == player or owner == player.UserId or owner == player.Name or owner == tostring(player.UserId) then
			return true
		end
	end
	return false
end

local function computeAssignment(player: Player): (boolean, Instance?)
	-- 1. Player attributes / value objects.
	for _, key in CONFIG.PlayerKeys do
		local value = readKey(player, key)
		if value ~= nil then
			if value == false or value == 0 or (type(value) == "number" and value < 0) then
				return false, nil
			elseif type(value) == "string" and isGuestString(value) then
				return false, nil
			end
			return true, resolvePlot(value)
		end
	end

	-- 2. Owner markers on plot models.
	for _, folder in getPlotFolders() do
		for _, plot in folder:GetChildren() do
			if ownsPlot(plot, player) then
				return true, plot
			end
		end
	end

	-- 3. Teams.
	local team = player.Team
	if team and not player.Neutral and not table.find(CONFIG.GuestTeams, team.Name) then
		for _, folder in getPlotFolders() do
			for _, plot in folder:GetChildren() do
				if plot.Name == team.Name then
					return true, plot
				end
				for _, key in CONFIG.TeamKeys do
					local value = readKey(plot, key)
					if value ~= nil and (value == team or value == team.TeamColor or tostring(value) == team.Name) then
						return true, plot
					end
				end
			end
		end
	end

	-- Everyone else is a guest.
	return false, nil
end

-- Whether the player is assigned to a plot, and the plot model if it can be found.
function PlotService.GetAssignment(player: Player): (boolean, Instance?)
	local now = os.clock()
	local cached = assignmentCache[player]
	if cached and now - cached.Time < CONFIG.AssignmentCacheTime then
		return cached.Assigned, cached.Plot
	end
	local assigned, plot = computeAssignment(player)
	assignmentCache[player] = { Time = now, Assigned = assigned, Plot = plot }
	return assigned, plot
end

function PlotService.IsAssigned(player: Player): boolean
	local assigned = PlotService.GetAssignment(player)
	return assigned
end

function PlotService.IsGuest(player: Player): boolean
	return not PlotService.IsAssigned(player)
end

-- World-space bounding box of every BasePart under `root`.
local function boundingBox(root: Instance): Box?
	local minV: Vector3? = nil
	local maxV: Vector3? = nil
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local cf = descendant.CFrame
			local half = descendant.Size / 2
			local extent = Vector3.new(
				math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z,
				math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z,
				math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
			)
			local low, high = cf.Position - extent, cf.Position + extent
			minV = if minV then minV:Min(low) else low
			maxV = if maxV then maxV:Max(high) else high
		end
	end
	if not minV or not maxV then
		return nil
	end
	return { CFrame = CFrame.new((minV + maxV) / 2), Size = maxV - minV }
end

-- Grows a box sideways by the padding and upwards by SafeZoneHeight.
local function extendUp(box: Box): Box
	local padding = CONFIG.SafeZonePadding
	local extra = CONFIG.SafeZoneHeight
	return {
		CFrame = box.CFrame * CFrame.new(0, extra / 2, 0),
		Size = box.Size + Vector3.new(padding * 2, extra, padding * 2),
	}
end

local function getSafeBoxes(plot: Instance): { Box }
	local now = os.clock()
	local cached = boundsCache[plot]
	if cached and now - cached.Time < CONFIG.BoundsCacheTime then
		return cached.Boxes
	end

	local boxes: { Box } = {}
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("BasePart") and table.find(CONFIG.SafeZoneNames, descendant.Name) then
			table.insert(boxes, extendUp({ CFrame = descendant.CFrame, Size = descendant.Size }))
		end
	end
	if #boxes == 0 then
		local box = if plot:IsA("BasePart") then { CFrame = plot.CFrame, Size = plot.Size } else boundingBox(plot)
		if box then
			table.insert(boxes, extendUp(box))
		end
	end

	boundsCache[plot] = { Time = now, Boxes = boxes }
	return boxes
end

local function pointInBox(box: Box, point: Vector3): boolean
	local localPoint = box.CFrame:PointToObjectSpace(point)
	local half = box.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- Whether `position` (default: the player's character) is inside the player's own tycoon.
function PlotService.IsInOwnSafeZone(player: Player, position: Vector3?): boolean
	local assigned, plot = PlotService.GetAssignment(player)
	if not assigned or not plot then
		return false
	end
	local point = position
	if not point then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return false
		end
		point = root.CFrame.Position
	end
	for _, box in getSafeBoxes(plot) do
		if pointInBox(box, point :: Vector3) then
			return true
		end
	end
	return false
end

-- Bosses may chase and hurt this player: alive, assigned to a plot and outside
-- their own tycoon.
function PlotService.CanBeTargeted(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	if not PlotService.IsAssigned(player) then
		return false
	end
	return not PlotService.IsInOwnSafeZone(player, root.CFrame.Position)
end

-- Same check for a character model (used by area damage).
function PlotService.CanCharacterBeTargeted(character: Model): boolean
	local player = Players:GetPlayerFromCharacter(character)
	return player ~= nil and PlotService.CanBeTargeted(player)
end

function PlotService.Start()
	Players.PlayerRemoving:Connect(function(player)
		assignmentCache[player] = nil
	end)

	local folders = getPlotFolders()
	if #folders > 0 then
		local names = {}
		for _, folder in folders do
			table.insert(names, `{folder:GetFullName()} ({#folder:GetChildren()} plots)`)
		end
		print(`[Plots] Looking for plot owners in: {table.concat(names, ", ")}`)
	else
		warn(
			`[Plots] No plot folder found in Workspace (looked for {table.concat(CONFIG.PlotFolders, ", ")}). `
				.. `Players only count as assigned through a "{CONFIG.PlayerKeys[1]}" attribute or value; everyone else is a guest that bosses ignore. `
				.. `Edit PlotService CONFIG to match your tycoon.`
				.. (if RunService:IsStudio() then " In Studio, chat !plot to assign yourself." else "")
		)
	end
end

return PlotService
