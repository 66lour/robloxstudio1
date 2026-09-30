--!strict
-- Builds boss models: a custom model from ServerStorage.BossModels when there
-- is one, otherwise a procedural rig styled from the roster's Appearance
-- (head shape, colors, material, features like horns, wings or a halo).
-- Everything is sized by the boss's Scale, so rarer bosses are bigger.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local BossSettings = require(script.Parent.BossSettings)

type BossDef = BossRoster.BossDef
type BossStats = BossRoster.BossStats

local BossBuilder = {}

BossBuilder.Tag = "Boss"

-- Rig proportions at scale 1 (HumanoidRootPart centre = origin, front = -Z).
local LEG_HEIGHT = 2

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

type Builder = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	Add: (self: Builder, name: string, size: Vector3, offset: CFrame, props: { [string]: any }?) -> Part,
}

local function newBuilder(model: Model, root: BasePart, scale: number): Builder
	local builder = {} :: Builder
	builder.Model = model
	builder.Root = root
	builder.Scale = scale
	function builder.Add(self: Builder, name: string, size: Vector3, offset: CFrame, props: { [string]: any }?): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * self.Scale
		-- Scale the offset's position but keep its rotation.
		part.CFrame = self.Root.CFrame * (offset - offset.Position + offset.Position * self.Scale)
		part.CanCollide = false
		part.CanQuery = true -- weapons can still hit limbs
		part.CanTouch = true
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if props then
			for key, value in props do
				(part :: any)[key] = value
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = self.Root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = self.Model
		return part
	end
	return builder
end

local function addHead(b: Builder, def: BossDef): Part
	local look = def.Appearance
	local headY = 1.7
	local head: Part
	local headDepth: number

	if look.Head == "Ball" then
		head = b:Add("Head", Vector3.new(1.45, 1.45, 1.45), CFrame.new(0, headY, 0), {
			Shape = Enum.PartType.Ball,
			Color = look.Body,
			Material = look.Material,
		})
		headDepth = 1.45
	elseif look.Head == "Pumpkin" then
		headY = 1.8
		head = b:Add("Head", Vector3.new(1.9, 1.55, 1.9), CFrame.new(0, headY, 0), {
			Shape = Enum.PartType.Ball,
			Color = look.Accent,
			Material = Enum.Material.SmoothPlastic,
		})
		headDepth = 1.9
		b:Add("Stem", Vector3.new(0.25, 0.45, 0.25), CFrame.new(0.05, headY + 0.9, 0) * CFrame.Angles(0, 0, math.rad(-12)), {
			Color = Color3.fromRGB(70, 90, 40),
			Material = Enum.Material.Wood,
		})
		-- Carved grin
		b:Add("Mouth", Vector3.new(0.9, 0.18, 0.1), CFrame.new(0, headY - 0.35, -headDepth / 2 + 0.12), {
			Color = look.Eyes,
			Material = Enum.Material.Neon,
		})
	elseif look.Head == "Skull" then
		head = b:Add("Head", Vector3.new(1.25, 1.2, 1.3), CFrame.new(0, headY + 0.05, 0), {
			Color = look.Body,
			Material = look.Material,
		})
		headDepth = 1.3
		b:Add("Jaw", Vector3.new(0.95, 0.35, 1.1), CFrame.new(0, headY - 0.62, -0.08), {
			Color = darken(look.Body, 0.15),
			Material = look.Material,
		})
	else
		head = b:Add("Head", Vector3.new(1.35, 1.25, 1.25), CFrame.new(0, headY, 0), {
			Color = look.Body,
			Material = look.Material,
		})
		headDepth = 1.25
	end

	for _, side in { -1, 1 } do
		local eye = b:Add("Eye", Vector3.new(0.24, 0.16, 0.08), CFrame.new(0.3 * side, headY + 0.1, -headDepth / 2 + 0.01), {
			Color = look.Eyes,
			Material = Enum.Material.Neon,
		})
		local glow = Instance.new("PointLight")
		glow.Color = look.Eyes
		glow.Range = 3 * b.Scale
		glow.Brightness = 1.5
		glow.Parent = eye
	end

	return head
end

local FEATURE_BUILDERS: { [string]: (b: Builder, def: BossDef) -> () } = {
	Horns = function(b, def)
		for _, side in { -1, 1 } do
			b:Add("Horn", Vector3.new(0.25, 1.1, 0.25), CFrame.new(0.55 * side, 2.55, 0) * CFrame.Angles(0, 0, math.rad(-28 * side)), {
				Color = def.Appearance.Accent,
				Material = Enum.Material.Slate,
			})
		end
	end,
	Crown = function(b, def)
		b:Add("CrownBand", Vector3.new(1.45, 0.22, 1.45), CFrame.new(0, 2.45, 0), {
			Color = def.Appearance.Accent,
			Material = Enum.Material.Metal,
		})
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			b:Add("CrownPoint", Vector3.new(0.18, 0.45, 0.18), CFrame.new(math.cos(angle) * 0.6, 2.75, math.sin(angle) * 0.6), {
				Color = def.Appearance.Accent,
				Material = Enum.Material.Neon,
			})
		end
	end,
	Hood = function(b, def)
		b:Add("Hood", Vector3.new(1.75, 1.6, 1.55), CFrame.new(0, 1.8, 0.28), {
			Color = darken(def.Appearance.Body, 0.35),
			Material = Enum.Material.Fabric,
		})
	end,
	Wings = function(b, def)
		for _, side in { -1, 1 } do
			b:Add(
				"Wing",
				Vector3.new(0.15, 3.2, 2.4),
				CFrame.new(1.7 * side, 1.2, 1.1) * CFrame.Angles(0, math.rad(35 * side), math.rad(-20 * side)),
				{
					Color = def.Appearance.Accent,
					Material = Enum.Material.Neon,
					Transparency = 0.3,
				}
			)
		end
	end,
	Halo = function(b, def)
		for i = 0, 9 do
			local angle = i / 10 * math.pi * 2
			b:Add("HaloBead", Vector3.new(0.22, 0.22, 0.22), CFrame.new(math.cos(angle) * 0.85, 3.1, math.sin(angle) * 0.85 + 0.2), {
				Shape = Enum.PartType.Ball,
				Color = def.Appearance.Accent,
				Material = Enum.Material.Neon,
			})
		end
	end,
	Spikes = function(b, def)
		for i = 0, 2 do
			b:Add("Spike", Vector3.new(0.3, 0.9, 0.3), CFrame.new(0, 0.8 - i * 0.7, 0.6) * CFrame.Angles(math.rad(40), 0, 0), {
				Color = def.Appearance.Accent,
				Material = Enum.Material.Slate,
			})
		end
	end,
	Pauldrons = function(b, def)
		for _, side in { -1, 1 } do
			b:Add("Pauldron", Vector3.new(1.45, 0.7, 1.4), CFrame.new(1.5 * side, 1.05, 0) * CFrame.Angles(0, 0, math.rad(-12 * side)), {
				Color = def.Appearance.Accent,
				Material = Enum.Material.Metal,
			})
		end
	end,
	FloatingOrbs = function(b, def)
		for i = 0, 2 do
			local angle = i / 3 * math.pi * 2
			local orb = b:Add("SoulOrb", Vector3.new(0.55, 0.55, 0.55), CFrame.new(math.cos(angle) * 2.6, 1.2 + (i % 2) * 0.6, math.sin(angle) * 2.6), {
				Shape = Enum.PartType.Ball,
				Color = def.Appearance.Aura,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
			})
			local light = Instance.new("PointLight")
			light.Color = def.Appearance.Aura
			light.Range = 4 * b.Scale
			light.Parent = orb
		end
	end,
	Floating = function() end, -- handled by the lower body
}

local function buildProcedural(def: BossDef, stats: BossStats): Model
	local look = def.Appearance
	local s = stats.Scale

	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * s
	root.CFrame = CFrame.new(0, (LEG_HEIGHT + 1) * s, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	local b = newBuilder(model, root, s)
	local torso = b:Add("Torso", Vector3.new(2, 2, 1), CFrame.new(), { Color = look.Body, Material = look.Material })
	b:Add("Belt", Vector3.new(2.05, 0.25, 1.05), CFrame.new(0, -0.85, 0), { Color = look.Accent, Material = Enum.Material.Neon })

	for _, side in { -1, 1 } do
		b:Add(if side < 0 then "LeftArm" else "RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5 * side, 0, 0), {
			Color = look.Body,
			Material = look.Material,
		})
	end

	if table.find(look.Features, "Floating") then
		b:Add("Robe", Vector3.new(2.3, 1.6, 1.3), CFrame.new(0, -1.8, 0), { Color = darken(look.Body, 0.3), Material = Enum.Material.Fabric })
		b:Add("RobeHem", Vector3.new(2.35, 0.15, 1.35), CFrame.new(0, -2.55, 0), {
			Color = look.Aura,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
	else
		for _, side in { -1, 1 } do
			b:Add(if side < 0 then "LeftLeg" else "RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5 * side, -2, 0), {
				Color = darken(look.Body, 0.2),
				Material = look.Material,
			})
		end
	end

	addHead(b, def)
	for _, feature in look.Features do
		FEATURE_BUILDERS[feature](b, def)
	end

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Color = ColorSequence.new(look.Aura)
	aura.LightEmission = 0.7
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = NumberSequence.new(0.4, 1)
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Rate = 12 + Rarities.Rank(def.Rarity) * 6
	aura.Parent = torso

	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = look.Aura
	light.Range = math.min(8 * s, 60)
	light.Brightness = 1.2
	light.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = LEG_HEIGHT * s
	humanoid.Parent = model

	return model
end

local function findCustomModel(def: BossDef): Model?
	local folder = ServerStorage:FindFirstChild(BossSettings.CustomModelFolderName)
	local template = folder and folder:FindFirstChild(def.Id)
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") and template.PrimaryPart then
		return template
	end
	return nil
end

local function addHealthBar(model: Model, def: BossDef, stats: BossStats)
	local rarity = Rarities.Get(def.Rarity)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	assert(head and head:IsA("BasePart"))

	local gui = Instance.new("BillboardGui")
	gui.Name = "BossHealthBar"
	gui.Size = UDim2.fromOffset(270, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 2 + stats.Scale * 0.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160 + stats.Scale * 20
	gui.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "BossName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 26)
	nameLabel.Font = Enum.Font.GrenzeGotisch
	nameLabel.TextSize = 26
	nameLabel.TextColor3 = rarity.Color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Text = def.Name
	nameLabel.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(0, 24)
	subtitle.Size = UDim2.new(1, 0, 0, 16)
	subtitle.Font = Enum.Font.Fondamento
	subtitle.TextSize = 14
	subtitle.TextColor3 = Color3.fromRGB(214, 204, 186)
	subtitle.TextStrokeTransparency = 0.4
	subtitle.Text = `{string.upper(def.Rarity)}  ·  {def.Title}`
	subtitle.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(10, 44)
	bar.Size = UDim2.new(1, -20, 0, 14)
	bar.BackgroundColor3 = Color3.fromRGB(18, 12, 16)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = rarity.Color
	barStroke.Thickness = 1.5
	barStroke.Transparency = 0.2
	barStroke.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fill
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(Color3.fromRGB(120, 14, 24), Color3.fromRGB(214, 40, 48))
	fillGradient.Parent = fill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.BackgroundTransparency = 1
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.Font = Enum.Font.Merriweather
	healthText.TextSize = 11
	healthText.TextColor3 = Color3.fromRGB(240, 232, 220)
	healthText.TextStrokeTransparency = 0.3
	healthText.ZIndex = 2
	healthText.Parent = bar
end

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function BossBuilder.UpdateHealthBar(model: Model, health: number, maxHealth: number)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	local gui = head and head:FindFirstChild("BossHealthBar")
	local bar = gui and gui:FindFirstChild("Bar")
	if not bar then
		return
	end
	local fill = bar:FindFirstChild("Fill") :: Frame?
	local text = bar:FindFirstChild("HealthText") :: TextLabel?
	local ratio = math.clamp(health / maxHealth, 0, 1)
	if fill then
		fill.Size = UDim2.fromScale(ratio, 1)
	end
	if text then
		text.Text = `{formatNumber(health)} / {formatNumber(maxHealth)}`
	end
end

-- Returns a ready-to-parent boss model at the world origin (use PivotTo).
function BossBuilder.Build(def: BossDef, stats: BossStats): Model
	local template = findCustomModel(def)
	local model: Model
	if template then
		model = template:Clone()
		model:ScaleTo(stats.Scale)
	else
		model = buildProcedural(def, stats)
	end
	model.Name = def.Name

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = stats.MaxHealth
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Seated } do
		humanoid:SetStateEnabled(state, false)
	end

	model:SetAttribute("BossId", def.Id)
	model:SetAttribute("Rarity", def.Rarity)
	CollectionService:AddTag(model, BossBuilder.Tag)

	addHealthBar(model, def, stats)
	BossBuilder.UpdateHealthBar(model, stats.MaxHealth, stats.MaxHealth)
	return model
end

return BossBuilder
