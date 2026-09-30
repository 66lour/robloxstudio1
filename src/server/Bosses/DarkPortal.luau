--!strict
-- The Dark Portal bosses emerge from.
--
-- Uses the first Workspace descendant named like BossSettings.PortalNames
-- (a Part or a Model). Bosses appear at an Attachment named "BossSpawn" inside
-- it if there is one, otherwise PortalSpawnDistance studs in front of it (its
-- LookVector side), facing away from it. If the map has no portal, a
-- placeholder is built at BossSettings.PlaceholderPortalPosition.
--
-- A billboard above the portal shows the countdown to the next boss.

local Workspace = game:GetService("Workspace")

local BossEffects = require(script.Parent.BossEffects)
local BossSettings = require(script.Parent.BossSettings)

local rgb = Color3.fromRGB

local DarkPortal = {}

local PORTAL_COLOR = rgb(150, 60, 255)

local portalInstance: Instance? = nil
local anchorPart: BasePart? = nil
local statusLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil

local function findPortal(): Instance?
	for _, name in BossSettings.PortalNames do
		local found = Workspace:FindFirstChild(name, true)
		if found and (found:IsA("BasePart") or found:IsA("Model")) then
			return found
		end
	end
	return nil
end

local function mainPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	local biggest: BasePart? = nil
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") and (not biggest or descendant.Size.Magnitude > biggest.Size.Magnitude) then
			biggest = descendant
		end
	end
	return biggest
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- A ring of obsidian stones around a swirling void, on a cobblestone dais.
local function buildPlaceholder(): Model
	local model = Instance.new("Model")
	model.Name = "DarkPortal"
	model:SetAttribute("Placeholder", true)
	local wanted = BossSettings.PlaceholderPortalPosition
	local ground = BossEffects.GroundAt(wanted + Vector3.new(0, 50, 0))
	if ground.Y > wanted.Y + 49 then
		-- Nothing below: build it at the configured height.
		ground = wanted
	end
	local base = CFrame.new(ground)
	local center = base * CFrame.new(0, 9, 0)

	local dais = part(model, {
		Name = "Dais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 26, 26),
		CFrame = base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Cobblestone,
		Color = rgb(70, 66, 76),
	})
	model.PrimaryPart = dais
	part(model, {
		Name = "Step",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 30, 30),
		CFrame = base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Cobblestone,
		Color = rgb(56, 54, 60),
	})
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		local stone = part(model, {
			Name = "ArchStone",
			Size = Vector3.new(2.6, 2.2, 2.2),
			CFrame = center * CFrame.new(math.cos(angle) * 8, math.sin(angle) * 8, 0) * CFrame.Angles(0, 0, angle),
			Material = Enum.Material.Glass,
			Color = rgb(24, 18, 32),
			Reflectance = 0.05,
		})
		if i % 2 == 0 then
			part(model, {
				Name = "Rune",
				Size = Vector3.new(0.3, 1.2, 0.1),
				CFrame = stone.CFrame * CFrame.new(0, 0, -1.12),
				Material = Enum.Material.Neon,
				Color = PORTAL_COLOR,
				CanCollide = false,
			})
		end
		if angle > 0.3 and angle < math.pi - 0.3 and i % 3 == 0 then
			part(model, {
				Name = "Spike",
				Size = Vector3.new(0.8, 3.2, 0.8),
				CFrame = center * CFrame.new(math.cos(angle) * 10, math.sin(angle) * 10, 0) * CFrame.Angles(0, 0, angle - math.pi / 2) * CFrame.Angles(0, math.pi / 4, 0),
				Material = Enum.Material.Basalt,
				Color = rgb(30, 26, 36),
			})
		end
	end
	local swirl = part(model, {
		Name = "Void",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 14.5, 14.5),
		CFrame = center * CFrame.Angles(0, math.pi / 2, 0),
		Material = Enum.Material.ForceField,
		Color = PORTAL_COLOR,
		Transparency = 0.15,
		CanCollide = false,
	})
	part(model, {
		Name = "VoidCore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 12, 12),
		CFrame = center * CFrame.Angles(0, math.pi / 2, 0),
		Material = Enum.Material.Neon,
		Color = rgb(20, 8, 36),
		CanCollide = false,
	})
	for _, side in { -1, 1 } do
		local brazier = part(model, {
			Name = "Brazier",
			Size = Vector3.new(2, 3.5, 2),
			CFrame = base * CFrame.new(side * 12, 2.95, -4),
			Material = Enum.Material.Metal,
			Color = rgb(40, 40, 46),
		})
		local fire = Instance.new("Fire")
		fire.Color = PORTAL_COLOR
		fire.SecondaryColor = rgb(20, 0, 40)
		fire.Size = 6
		fire.Heat = 12
		fire.Parent = brazier
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(PORTAL_COLOR, rgb(40, 0, 80))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 30
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Parent = swirl
	local light = Instance.new("PointLight")
	light.Color = PORTAL_COLOR
	light.Range = 40
	light.Brightness = 3
	light.Parent = swirl

	local spawnAttachment = Instance.new("Attachment")
	spawnAttachment.Name = "BossSpawn"
	spawnAttachment.WorldCFrame = base * CFrame.new(0, 1.3, -16)
	spawnAttachment.Parent = dais

	model.Parent = Workspace
	warn(`[Bosses] No Dark Portal found in Workspace (looked for {table.concat(BossSettings.PortalNames, ", ")}). Built a placeholder at {tostring(ground)}; add your own part or model named "DarkPortal" to replace it.`)
	return model
end

local function buildDisplay(anchor: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossCountdown"
	gui.Size = UDim2.fromOffset(360, 84)
	gui.StudsOffsetWorldSpace = Vector3.new(0, anchor.Size.Y / 2 + 22, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = anchor

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Font = Enum.Font.GrenzeGotisch
	title.TextSize = 30
	title.TextColor3 = rgb(200, 150, 255)
	title.TextStrokeTransparency = 0.2
	title.Text = "The Dark Portal"
	title.Parent = gui

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(0, 30)
	status.Size = UDim2.new(1, 0, 0, 20)
	status.Font = Enum.Font.Fondamento
	status.TextSize = 17
	status.TextColor3 = rgb(226, 214, 196)
	status.TextStrokeTransparency = 0.3
	status.Parent = gui
	statusLabel = status

	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Position = UDim2.fromOffset(0, 50)
	timer.Size = UDim2.new(1, 0, 0, 30)
	timer.Font = Enum.Font.Merriweather
	timer.TextSize = 24
	timer.TextColor3 = rgb(244, 178, 64)
	timer.TextStrokeTransparency = 0.2
	timer.Parent = gui
	timerLabel = timer
end

function DarkPortal.Setup()
	portalInstance = findPortal() or buildPlaceholder()
	anchorPart = mainPart(portalInstance :: Instance)
	assert(anchorPart, "The Dark Portal has no parts")
	if BossSettings.ShowPortalCountdown then
		buildDisplay(anchorPart :: BasePart)
	end
end

-- Where the next boss appears (standing on the ground) and which way it faces.
function DarkPortal.GetSpawnCFrame(): CFrame
	local anchor = anchorPart :: BasePart
	local instance = portalInstance :: Instance
	local marker = instance:FindFirstChild("BossSpawn", true)
	local position: Vector3
	local facing: Vector3
	if marker and marker:IsA("Attachment") then
		position = marker.WorldPosition
		facing = marker.WorldCFrame.LookVector
	elseif marker and marker:IsA("BasePart") then
		position = marker.Position
		facing = marker.CFrame.LookVector
	else
		local pivot = if instance:IsA("Model") then instance:GetPivot() else anchor.CFrame
		facing = pivot.LookVector
		position = pivot.Position + Vector3.new(facing.X, 0, facing.Z).Unit * BossSettings.PortalSpawnDistance
	end
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude < 0.01 then
		flatFacing = Vector3.new(0, 0, -1)
	end
	local ground = BossEffects.GroundAt(position + Vector3.new(0, 6, 0), { instance })
	return CFrame.lookAt(ground, ground + flatFacing.Unit)
end

function DarkPortal.GetPosition(): Vector3
	return (anchorPart :: BasePart).Position
end

function DarkPortal.Burst(color: Color3?)
	local anchor = anchorPart :: BasePart
	BossEffects.PortalBurst(DarkPortal.GetSpawnCFrame().Position, color or PORTAL_COLOR, 12)
	BossEffects.Shockwave(anchor.Position, 16, color or PORTAL_COLOR)
end

-- Updates the billboard: `bossName` while a boss is loose, otherwise the countdown.
function DarkPortal.SetStatus(bossName: string?, secondsLeft: number?)
	local status, timer = statusLabel, timerLabel
	if not status or not timer then
		return
	end
	if bossName then
		status.Text = `{bossName} stalks the castle`
		timer.Text = "Slay it to seal the portal"
	elseif secondsLeft then
		local seconds = math.max(0, math.ceil(secondsLeft))
		status.Text = "The next horror emerges in"
		timer.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
	end
end

return DarkPortal
