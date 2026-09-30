--!strict
-- Boss abilities. Each boss in BossRoster lists abilities by Kind with its own
-- parameters; anything it leaves out comes from DEFAULTS below. Every ability
-- telegraphs before it hits, so players can dodge.
--
--   Slam   – ground circle around the boss, then a heavy hit
--   Charge – warning strip, then a fast dash that hits everyone in its path
--   Blink  – teleports behind its target and strikes the area
--   Drain  – channels, damaging nearby players and healing from it
--   Meteor – rains orbs on players' positions
--   Nova   – large burst around the boss that also slows
--
-- Only players who may be targeted (assigned to a plot and outside their own
-- tycoon, see PlotService) are ever hit; guests can't be hurt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local BossEffects = require(script.Parent.BossEffects)

type BossDef = BossRoster.BossDef
type BossStats = BossRoster.BossStats

export type Context = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Def: BossDef,
	Stats: BossStats,
	Color: Color3,
	TargetRoot: BasePart,
	GetDamage: () -> number, -- current base damage (includes enrage)
	GetWalkSpeed: () -> number, -- current walk speed (includes enrage)
	IsAlive: () -> boolean,
	-- Tells clients to play an animation (see client ActionPoses).
	PlayAction: (name: string, windup: number, duration: number?) -> (),
}

type Spec = { [string]: any }

local BossAbilities = {}

local DEFAULTS: { [string]: Spec } = {
	Slam = { Cooldown = 10, Radius = 12, Windup = 1.3, DamageMult = 1.6 },
	Charge = { Cooldown = 12, Speed = 40, Windup = 0.9, HitRadius = 6, DamageMult = 1.4, MaxDistance = 80 },
	Blink = { Cooldown = 10, Radius = 9, Windup = 0.45, DamageMult = 1.5 },
	Drain = { Cooldown = 14, Duration = 3, Radius = 14, DamageMult = 0.4, HealRatio = 1 },
	Meteor = { Cooldown = 12, Count = 4, Radius = 8, Windup = 1.4, DamageMult = 1.4, Range = 60 },
	Nova = { Cooldown = 14, Radius = 18, Windup = 1.3, DamageMult = 1, SlowFactor = 0.5, SlowDuration = 3 },
}

local TICK = 0.5 -- Drain damage interval

-- Fills in missing ability parameters from DEFAULTS.
function BossAbilities.Resolve(spec: Spec): Spec
	local resolved = table.clone(DEFAULTS[spec.Kind])
	for key, value in spec do
		resolved[key] = value
	end
	return resolved
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Living, targetable player humanoids within `radius` (horizontally) of `center`.
local function humanoidsInRadius(center: Vector3, radius: number): { Humanoid }
	local found = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 and PlotService.CanBeTargeted(player) then
			local offset = root.Position - center
			if flat(offset).Magnitude <= radius + 1 and math.abs(offset.Y) <= 12 + radius * 0.4 then
				table.insert(found, humanoid)
			end
		end
	end
	return found
end
BossAbilities.HumanoidsInRadius = humanoidsInRadius

local function hold(ctx: Context)
	ctx.Humanoid:MoveTo(ctx.Root.Position)
end

local function face(ctx: Context, position: Vector3)
	local from = ctx.Root.Position
	local to = Vector3.new(position.X, from.Y, position.Z)
	if flat(to - from).Magnitude > 0.1 then
		ctx.Root.CFrame = CFrame.lookAt(from, to)
	end
end

local function hitArea(ctx: Context, center: Vector3, radius: number, damageMult: number)
	BossEffects.Shockwave(center, radius, ctx.Color)
	local damage = ctx.GetDamage() * damageMult
	for _, humanoid in humanoidsInRadius(center, radius) do
		humanoid:TakeDamage(damage)
	end
end

local RUNNERS: { [string]: (ctx: Context, spec: Spec) -> () } = {}

function RUNNERS.Slam(ctx, spec)
	hold(ctx)
	ctx.PlayAction("Slam", spec.Windup)
	local center = ctx.Root.Position
	BossEffects.Telegraph(center, spec.Radius, spec.Windup, ctx.Color)
	task.wait(spec.Windup)
	if ctx.IsAlive() then
		hitArea(ctx, BossEffects.GroundAt(center), spec.Radius, spec.DamageMult)
	end
end

function RUNNERS.Charge(ctx, spec)
	hold(ctx)
	local start = ctx.Root.Position
	local toTarget = flat(ctx.TargetRoot.Position - start)
	if toTarget.Magnitude < 1 then
		return
	end
	local direction = toTarget.Unit
	local distance = math.min(toTarget.Magnitude + 10, spec.MaxDistance)
	local finish = start + direction * distance

	face(ctx, finish)
	ctx.PlayAction("Charge", spec.Windup, spec.Windup + distance / spec.Speed)
	BossEffects.LineTelegraph(start, finish, spec.HitRadius * 2, spec.Windup, ctx.Color)
	task.wait(spec.Windup)
	if not ctx.IsAlive() then
		return
	end

	ctx.Humanoid.WalkSpeed = spec.Speed
	ctx.Humanoid:MoveTo(finish)
	local alreadyHit: { [Humanoid]: boolean } = {}
	local damage = ctx.GetDamage() * spec.DamageMult
	local deadline = os.clock() + distance / spec.Speed + 0.4
	while os.clock() < deadline and ctx.IsAlive() do
		for _, humanoid in humanoidsInRadius(ctx.Root.Position, spec.HitRadius) do
			if not alreadyHit[humanoid] then
				alreadyHit[humanoid] = true
				humanoid:TakeDamage(damage)
			end
		end
		if flat(finish - ctx.Root.Position).Magnitude < 3 then
			break
		end
		task.wait(0.05)
	end
	if ctx.IsAlive() then
		ctx.Humanoid.WalkSpeed = ctx.GetWalkSpeed()
		hold(ctx)
	end
end

function RUNNERS.Blink(ctx, spec)
	local targetRoot = ctx.TargetRoot
	ctx.PlayAction("Blink", spec.Windup)
	BossEffects.Shockwave(ctx.Root.Position, 4 * ctx.Stats.Scale, Color3.new(0, 0, 0))

	-- Appear behind the target, standing on the ground.
	local behind = (targetRoot.CFrame * CFrame.new(0, 0, 4 + ctx.Stats.Scale * 1.5)).Position
	local ground = BossEffects.GroundAt(behind, { ctx.Model :: Instance })
	local height = ctx.Humanoid.HipHeight + ctx.Root.Size.Y / 2
	local destination = ground + Vector3.new(0, height, 0)
	local lookAt = Vector3.new(targetRoot.Position.X, destination.Y, targetRoot.Position.Z)
	if flat(lookAt - destination).Magnitude < 0.1 then
		lookAt = destination + Vector3.new(0, 0, -1)
	end
	ctx.Model:PivotTo(CFrame.lookAt(destination, lookAt))
	hold(ctx)

	BossEffects.Shockwave(destination, 4 * ctx.Stats.Scale, ctx.Color)
	BossEffects.Telegraph(destination, spec.Radius, spec.Windup, ctx.Color)
	task.wait(spec.Windup)
	if ctx.IsAlive() then
		hitArea(ctx, ground, spec.Radius, spec.DamageMult)
	end
end

local function tether(from: BasePart, toCharacter: Model, color: Color3)
	local toRoot = toCharacter:FindFirstChild("HumanoidRootPart")
	if not toRoot then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = from
	local a1 = Instance.new("Attachment")
	a1.Parent = toRoot
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.Width0 = 1.2
	beam.Width1 = 0.3
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.Parent = from
	task.delay(TICK, function()
		beam:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end

function RUNNERS.Drain(ctx, spec)
	hold(ctx)
	ctx.PlayAction("Drain", 0.6, 0.6 + spec.Duration)
	BossEffects.Telegraph(ctx.Root.Position, spec.Radius, 0.6, ctx.Color)
	task.wait(0.6)

	for _ = 1, math.max(1, math.floor(spec.Duration / TICK)) do
		if not ctx.IsAlive() then
			return
		end
		hold(ctx)
		local drained = 0
		local damage = ctx.GetDamage() * spec.DamageMult
		for _, humanoid in humanoidsInRadius(ctx.Root.Position, spec.Radius) do
			local before = humanoid.Health
			humanoid:TakeDamage(damage)
			drained += before - humanoid.Health
			local character = humanoid.Parent
			if character and character:IsA("Model") then
				tether(ctx.Root, character, ctx.Color)
			end
		end
		if drained > 0 then
			local humanoid = ctx.Humanoid
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + drained * spec.HealRatio)
		end
		task.wait(TICK)
	end
end

function RUNNERS.Meteor(ctx, spec)
	hold(ctx)
	ctx.PlayAction("Meteor", spec.Windup)
	local targets: { Vector3 } = {}
	for _, humanoid in humanoidsInRadius(ctx.Root.Position, spec.Range) do
		local root = (humanoid.Parent :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(targets, root.Position)
		end
	end
	if #targets == 0 then
		table.insert(targets, ctx.TargetRoot.Position)
	end

	-- One meteor per player first, then scatter the rest around random players.
	local impacts: { Vector3 } = {}
	for i = 1, spec.Count do
		local base = targets[((i - 1) % #targets) + 1]
		if i > #targets then
			local angle = math.random() * math.pi * 2
			local spread = spec.Radius + math.random() * 10
			base += Vector3.new(math.cos(angle) * spread, 0, math.sin(angle) * spread)
		end
		table.insert(impacts, base)
	end

	for index, point in impacts do
		-- Stagger slightly so the volley reads as a rain, not one blast.
		local delay = spec.Windup + (index - 1) * 0.12
		BossEffects.Telegraph(point, spec.Radius, delay, spec.Color or ctx.Color)
		BossEffects.FallingOrb(point, math.max(2, spec.Radius * 0.5), delay, spec.Color or ctx.Color)
		task.delay(delay, function()
			if ctx.IsAlive() then
				local ground = BossEffects.GroundAt(point)
				BossEffects.Shockwave(ground, spec.Radius, spec.Color or ctx.Color)
				local damage = ctx.GetDamage() * spec.DamageMult
				for _, humanoid in humanoidsInRadius(ground, spec.Radius) do
					humanoid:TakeDamage(damage)
				end
			end
		end)
	end
	task.wait(0.6)
end

function RUNNERS.Nova(ctx, spec)
	hold(ctx)
	ctx.PlayAction("Nova", spec.Windup)
	local center = ctx.Root.Position
	BossEffects.Telegraph(center, spec.Radius, spec.Windup, ctx.Color)
	task.wait(spec.Windup)
	if not ctx.IsAlive() then
		return
	end
	local ground = BossEffects.GroundAt(center)
	BossEffects.Shockwave(ground, spec.Radius, ctx.Color)
	local damage = ctx.GetDamage() * spec.DamageMult
	for _, humanoid in humanoidsInRadius(ground, spec.Radius) do
		humanoid:TakeDamage(damage)
		if not humanoid:GetAttribute("BossSlowed") then
			local original = humanoid.WalkSpeed
			humanoid:SetAttribute("BossSlowed", true)
			humanoid.WalkSpeed = original * spec.SlowFactor
			task.delay(spec.SlowDuration, function()
				if humanoid.Parent then
					humanoid.WalkSpeed = original
					humanoid:SetAttribute("BossSlowed", nil)
				end
			end)
		end
	end
end

-- Whether `spec` makes sense right now, given the distance to the target.
function BossAbilities.CanUse(spec: Spec, distance: number): boolean
	local kind = spec.Kind
	if kind == "Slam" or kind == "Nova" or kind == "Drain" then
		return distance <= spec.Radius * 0.85
	elseif kind == "Charge" then
		return distance >= 14 and distance <= spec.MaxDistance
	elseif kind == "Blink" then
		return distance >= 12
	elseif kind == "Meteor" then
		return distance <= spec.Range
	end
	return false
end

-- Runs an ability to completion (yields for its cast time).
function BossAbilities.Run(ctx: Context, spec: Spec)
	local runner = RUNNERS[spec.Kind]
	assert(runner, `No runner for ability "{tostring(spec.Kind)}"`)
	local ok, err = pcall(runner :: any, ctx, spec)
	if not ok then
		warn(`[Bosses] {ctx.Def.Name} ability {spec.Kind} errored: {err}`)
	end
	if ctx.IsAlive() then
		ctx.Humanoid.WalkSpeed = ctx.GetWalkSpeed()
	end
end

return BossAbilities
