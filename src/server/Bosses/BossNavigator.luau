--!strict
-- Moves a boss toward a point: straight there when the way is clear, around
-- obstacles with PathfindingService when it isn't, and re-plans when it gets
-- stuck or the target moves.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BossSettings = require(script.Parent.BossSettings)

local REPATH_DISTANCE = 10
local REPATH_AGE = 2.5
local STUCK_TIME = 1.5
local STUCK_DISTANCE = 1

local BossNavigator = {}
BossNavigator.__index = BossNavigator

export type Navigator = typeof(setmetatable(
	{} :: {
		Model: Model,
		Humanoid: Humanoid,
		Root: BasePart,
		Scale: number,
		Path: Path,
		Waypoints: { PathWaypoint }?,
		Index: number,
		Goal: Vector3?,
		ComputedAt: number,
		ProgressAt: number,
		ProgressPosition: Vector3,
		Params: RaycastParams,
	},
	BossNavigator
))

function BossNavigator.new(model: Model, humanoid: Humanoid, root: BasePart, scale: number): Navigator
	local extents = model:GetExtentsSize()
	local path = PathfindingService:CreatePath({
		AgentRadius = math.max(2, math.min(root.Size.X, root.Size.Z) * 0.6),
		AgentHeight = math.max(5, extents.Y * 0.8),
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = math.max(4, scale * 2),
	})
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	return setmetatable({
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Scale = scale,
		Path = path,
		Waypoints = nil,
		Index = 0,
		Goal = nil,
		ComputedAt = 0,
		ProgressAt = os.clock(),
		ProgressPosition = root.Position,
		Params = params,
	}, BossNavigator)
end

-- True when nothing solid stands between the boss and `target` at waist height.
function BossNavigator.IsClear(self: Navigator, target: Vector3): boolean
	local exclude: { Instance } = { self.Model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local effects = Workspace:FindFirstChild("BossEffects")
	if effects then
		table.insert(exclude, effects)
	end
	self.Params.FilterDescendantsInstances = exclude
	local origin = self.Root.Position
	local flatTarget = Vector3.new(target.X, origin.Y, target.Z)
	local direction = flatTarget - origin
	if direction.Magnitude < 1 then
		return true
	end
	local result = Workspace:Raycast(origin, direction, self.Params)
	return result == nil or not (result.Instance :: BasePart).CanCollide
end

function BossNavigator.Stop(self: Navigator)
	self.Waypoints = nil
	self.Humanoid:MoveTo(self.Root.Position)
end

local function compute(self: Navigator, target: Vector3)
	self.ComputedAt = os.clock()
	self.Goal = target
	local ok = pcall(function()
		self.Path:ComputeAsync(self.Root.Position, target)
	end)
	if ok and self.Path.Status == Enum.PathStatus.Success then
		self.Waypoints = self.Path:GetWaypoints()
		self.Index = 2
	else
		self.Waypoints = nil
	end
end

function BossNavigator.MoveTo(self: Navigator, target: Vector3)
	local now = os.clock()
	local position = self.Root.Position

	-- Track progress so a boss walking into a wall notices it's stuck.
	local stuck = false
	if (position - self.ProgressPosition).Magnitude > STUCK_DISTANCE then
		self.ProgressPosition = position
		self.ProgressAt = now
	elseif now - self.ProgressAt > STUCK_TIME then
		stuck = true
		self.ProgressAt = now
	end

	if not BossSettings.Pathfinding or (not stuck and self:IsClear(target)) then
		self.Waypoints = nil
		self.Humanoid:MoveTo(target)
		return
	end

	local goalMoved = self.Goal == nil or (self.Goal - target).Magnitude > REPATH_DISTANCE
	if stuck or goalMoved or not self.Waypoints or now - self.ComputedAt > REPATH_AGE then
		compute(self, target)
	end

	local waypoints = self.Waypoints
	if not waypoints then
		self.Humanoid:MoveTo(target)
		return
	end
	local reach = 2 + self.Scale
	while self.Index <= #waypoints do
		local waypoint = waypoints[self.Index].Position
		if Vector3.new(waypoint.X - position.X, 0, waypoint.Z - position.Z).Magnitude > reach then
			self.Humanoid:MoveTo(waypoint)
			return
		end
		self.Index += 1
	end
	self.Waypoints = nil
	self.Humanoid:MoveTo(target)
end

return BossNavigator
