--!strict
-- Server-side visuals for bosses: attack telegraphs, impacts, meteors, the
-- death dissolve and the loot burst. Everything is anchored, non-colliding and
-- cleaned up automatically.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ItemCatalog = require(ReplicatedStorage.Shared.Config.ItemCatalog)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local BossEffects = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "BossEffects"
effectsFolder.Parent = Workspace

BossEffects.Folder = effectsFolder

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = effectsFolder
	return part
end

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- Finds the ground below `position`, ignoring effects, bosses and characters.
function BossEffects.GroundAt(position: Vector3, ignore: { Instance }?): Vector3
	local exclude: { Instance } = { effectsFolder }
	local bossFolder = Workspace:FindFirstChild("Bosses")
	if bossFolder then
		table.insert(exclude, bossFolder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	if ignore then
		for _, instance in ignore do
			table.insert(exclude, instance)
		end
	end
	groundParams.FilterDescendantsInstances = exclude

	local result = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -200, 0), groundParams)
	return if result then result.Position else position
end

local FLAT = CFrame.Angles(0, 0, math.rad(90))

-- A circular warning on the ground that fills up over `duration` seconds.
function BossEffects.Telegraph(position: Vector3, radius: number, duration: number, color: Color3)
	local ground = BossEffects.GroundAt(position)
	local diameter = radius * 2
	local base = CFrame.new(ground + Vector3.new(0, 0.08, 0)) * FLAT

	local outline = makePart({
		Name = "TelegraphOutline",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, diameter, diameter),
		CFrame = base,
		Color = color,
		Transparency = 0.8,
	})
	local fill = makePart({
		Name = "TelegraphFill",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 0.5, 0.5),
		CFrame = base * CFrame.new(0.02, 0, 0),
		Color = color,
		Transparency = 0.45,
	})
	tween(fill, duration, { Size = Vector3.new(0.12, diameter, diameter) }, Enum.EasingStyle.Linear)
	Debris:AddItem(outline, duration + 0.05)
	Debris:AddItem(fill, duration + 0.05)
end

-- A straight warning strip from `from` to `to` (used by charges).
function BossEffects.LineTelegraph(from: Vector3, to: Vector3, width: number, duration: number, color: Color3)
	local a = BossEffects.GroundAt(from)
	local b = BossEffects.GroundAt(to)
	local flatB = Vector3.new(b.X, a.Y, b.Z)
	local length = (flatB - a).Magnitude
	if length < 0.5 then
		return
	end
	local strip = makePart({
		Name = "TelegraphLine",
		Size = Vector3.new(width, 0.12, length),
		CFrame = CFrame.lookAt(a:Lerp(flatB, 0.5), flatB) + Vector3.new(0, 0.1, 0),
		Color = color,
		Transparency = 0.8,
	})
	tween(strip, duration, { Transparency = 0.4 }, Enum.EasingStyle.Linear)
	Debris:AddItem(strip, duration + 0.05)
end

-- An expanding, fading sphere where an attack lands.
function BossEffects.Shockwave(position: Vector3, radius: number, color: Color3)
	local sphere = makePart({
		Name = "Shockwave",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.3,
		Material = Enum.Material.ForceField,
	})
	tween(sphere, 0.45, { Size = Vector3.one * radius * 2, Transparency = 1 })
	Debris:AddItem(sphere, 0.5)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(radius * 2, 60)
	light.Brightness = 4
	light.Parent = sphere
end

-- A glowing ball that falls from the sky onto `target` over `duration` seconds.
function BossEffects.FallingOrb(target: Vector3, size: number, duration: number, color: Color3)
	local ground = BossEffects.GroundAt(target)
	local orb = makePart({
		Name = "Meteor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(ground + Vector3.new(6, 70, 6)),
		Color = color,
	})
	local fire = Instance.new("Fire")
	fire.Color = color
	fire.SecondaryColor = Color3.new(0, 0, 0)
	fire.Size = size * 1.5
	fire.Parent = orb
	tween(orb, duration, { CFrame = CFrame.new(ground) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(orb, duration + 0.05)
end

-- Fades a defeated boss away with a burst of particles in its aura color.
function BossEffects.Dissolve(model: Model, color: Color3, duration: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			if descendant.Transparency < 1 then
				tween(descendant, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)
			end
		elseif descendant:IsA("Decal") then
			tween(descendant, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = false
		end
	end

	local root = model.PrimaryPart
	if root then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color, Color3.new(0, 0, 0))
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, root.Size.Y * 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(4, 14)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 6, 0)
		emitter.Rate = 0
		emitter.Parent = root
		emitter:Emit(80)
	end
end

-- Rarity-colored orbs bursting out of a defeated boss, plus a pillar of light
-- for Legendary and Mythic drops.
function BossEffects.LootBurst(position: Vector3, drops: { ItemCatalog.ItemDef })
	local ground = BossEffects.GroundAt(position)
	local bestRank = 0
	local bestColor = Color3.new(1, 1, 1)

	for index, item in drops do
		local rarity = Rarities.Get(item.Rarity)
		if rarity.Rank > bestRank then
			bestRank = rarity.Rank
			bestColor = rarity.Color
		end

		local angle = (index / #drops) * math.pi * 2
		local landing = ground + Vector3.new(math.cos(angle) * 6, 1.5, math.sin(angle) * 6)
		local orb = makePart({
			Name = "LootOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (1 + rarity.Rank * 0.2),
			CFrame = CFrame.new(ground + Vector3.new(0, 3, 0)),
			Color = rarity.Color,
		})
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 10 + rarity.Rank * 2
		light.Brightness = 3
		light.Parent = orb

		local apex = ground:Lerp(landing, 0.5) + Vector3.new(0, 10, 0)
		tween(orb, 0.45, { CFrame = CFrame.new(apex) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.45, function()
			tween(orb, 0.45, { CFrame = CFrame.new(landing) }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
			task.delay(2.5, function()
				tween(orb, 1, { Transparency = 1, Size = Vector3.one * 0.2 })
			end)
		end)
		Debris:AddItem(orb, 4.2)
	end

	if bestRank >= Rarities.Rank("Legendary") then
		local height = 120
		local pillar = makePart({
			Name = "LootPillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 3, 3),
			CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * FLAT,
			Color = bestColor,
			Transparency = 0.35,
		})
		tween(pillar, 5, { Transparency = 1, Size = Vector3.new(height, 0.5, 0.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		Debris:AddItem(pillar, 5.1)
	end
end

return BossEffects
