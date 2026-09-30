--!strict
-- Built-in looks for the weapons in WeaponCatalog, used when ServerStorage.Weapons
-- has no Tool with that name. Each Tool's Handle is the grip; the blade runs
-- along the Handle's +Z axis, which the Grip below points straight up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local WeaponCatalog = require(ReplicatedStorage.Shared.Config.WeaponCatalog)

type WeaponDef = WeaponCatalog.WeaponDef

local rgb = Color3.fromRGB

local WeaponModels = {}

-- Hold point at the Handle's centre with the blade (+Z) pointing up.
local GRIP = CFrame.fromMatrix(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0))

type Look = { Material: Enum.Material, Color: Color3, Transparency: number? }

local LOOKS: { [string]: Look } = {
	Wood = { Material = Enum.Material.Wood, Color = rgb(96, 68, 44) },
	DarkWood = { Material = Enum.Material.Wood, Color = rgb(60, 44, 34) },
	Rust = { Material = Enum.Material.CorrodedMetal, Color = rgb(128, 86, 58) },
	Iron = { Material = Enum.Material.Metal, Color = rgb(110, 114, 122) },
	DarkIron = { Material = Enum.Material.Metal, Color = rgb(44, 46, 54) },
	Bone = { Material = Enum.Material.Limestone, Color = rgb(222, 212, 188) },
	Leather = { Material = Enum.Material.Leather, Color = rgb(70, 46, 34) },
	Gold = { Material = Enum.Material.Metal, Color = rgb(214, 172, 90) },
	Obsidian = { Material = Enum.Material.Glass, Color = rgb(24, 18, 32) },
	Pumpkin = { Material = Enum.Material.SmoothPlastic, Color = rgb(222, 110, 24) },
}

type Builder = {
	Tool: Tool,
	Handle: BasePart,
}

local function add(builder: Builder, name: string, size: Vector3, cf: CFrame, look: Look | Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cf
	if typeof(look) == "Color3" then
		part.Material = Enum.Material.Neon
		part.Color = look
	else
		part.Material = look.Material
		part.Color = look.Color
		part.Transparency = look.Transparency or 0
	end
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = builder.Handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = builder.Tool
	return part
end

-- A bar from z = a to z = b along the blade axis (optionally offset sideways).
local function bar(builder: Builder, name: string, a: number, b: number, width: number, thickness: number, look: Look | Color3, x: number?, y: number?): Part
	return add(builder, name, Vector3.new(width, thickness, b - a), CFrame.new(x or 0, y or 0, (a + b) / 2), look)
end

local function trail(builder: Builder, part: BasePart, a: Vector3, b: Vector3, color: Color3)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailStart"
	a0.Position = a
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailEnd"
	a1.Position = b
	a1.Parent = part
	local swing = Instance.new("Trail")
	swing.Name = "SwingTrail"
	swing.Attachment0 = a0
	swing.Attachment1 = a1
	swing.Color = ColorSequence.new(color)
	swing.LightEmission = 1
	swing.Lifetime = 0.25
	swing.Transparency = NumberSequence.new(0.2, 1)
	swing.Enabled = false
	swing.Parent = part
end

local BUILDERS: { [string]: (Builder, Color3) -> () } = {}

BUILDERS.Stake = function(b, _)
	bar(b, "Shaft", 0.6, 2.6, 0.32, 0.32, LOOKS.Wood)
	local tip = add(b, "Point", Vector3.new(0.22, 0.22, 0.7), CFrame.new(0, 0, 2.9) * CFrame.Angles(0, 0, math.pi / 4), LOOKS.Wood)
	bar(b, "Binding", 0.5, 0.75, 0.38, 0.38, LOOKS.Leather)
	trail(b, tip, Vector3.new(0, 0, -1.2), Vector3.new(0, 0, 0.3), rgb(200, 180, 150))
end

BUILDERS.Carver = function(b, glow)
	add(b, "Pommel", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0, -0.6), LOOKS.Pumpkin, Enum.PartType.Ball)
	bar(b, "Guard", 0.45, 0.6, 0.8, 0.14, LOOKS.Rust)
	local blade = add(b, "Blade", Vector3.new(0.5, 0.08, 1.2), CFrame.new(0.05, 0, 1.2), LOOKS.Rust)
	add(b, "BladeCurve", Vector3.new(0.4, 0.08, 0.8), CFrame.new(0.2, 0, 2.1) * CFrame.Angles(0, 0.35, 0), LOOKS.Rust)
	add(b, "Tip", Vector3.new(0.25, 0.08, 0.5), CFrame.new(0.42, 0, 2.6) * CFrame.Angles(0, 0.7, 0), LOOKS.Rust)
	add(b, "Edge", Vector3.new(0.06, 0.1, 1.9), CFrame.new(-0.2, 0, 1.6) * CFrame.Angles(0, 0.15, 0), glow)
	trail(b, blade, Vector3.new(0, 0, -0.6), Vector3.new(0.4, 0, 1.6), glow)
end

BUILDERS.Spade = function(b, glow)
	bar(b, "Shaft", 0.5, 3.6, 0.26, 0.26, LOOKS.DarkWood)
	bar(b, "Grip", -0.9, -0.5, 0.7, 0.18, LOOKS.DarkWood)
	local head = add(b, "SpadeHead", Vector3.new(1.1, 0.12, 1.3), CFrame.new(0, 0, 4.2), LOOKS.Iron)
	add(b, "SpadeLip", Vector3.new(0.7, 0.12, 0.3), CFrame.new(0, 0, 4.95), LOOKS.Iron)
	add(b, "Rune", Vector3.new(0.12, 0.14, 0.7), CFrame.new(0, 0, 4.15), glow)
	trail(b, head, Vector3.new(0, 0, -0.6), Vector3.new(0, 0, 0.6), glow)
end

BUILDERS.Axe = function(b, glow)
	bar(b, "Haft", 0.5, 3.2, 0.3, 0.3, LOOKS.Bone)
	add(b, "Knob", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, -0.55), LOOKS.Bone, Enum.PartType.Ball)
	local head = add(b, "AxeHead", Vector3.new(1.3, 0.16, 1.1), CFrame.new(0.65, 0, 3.0), LOOKS.Rust)
	add(b, "AxeBeard", Vector3.new(0.5, 0.16, 0.7), CFrame.new(1.25, 0, 2.7) * CFrame.Angles(0, 0.5, 0), LOOKS.Rust)
	add(b, "Spike", Vector3.new(0.6, 0.16, 0.2), CFrame.new(-0.35, 0, 3.0), LOOKS.DarkIron)
	add(b, "Edge", Vector3.new(0.08, 0.2, 1.2), CFrame.new(1.32, 0, 3.0), glow)
	trail(b, head, Vector3.new(0.6, 0, -0.5), Vector3.new(0.6, 0, 0.5), glow)
end

local function sword(b: Builder, glow: Color3, length: number, width: number, blade: Look, hilt: Look, guard: number)
	add(b, "Pommel", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, -0.65), hilt, Enum.PartType.Ball)
	bar(b, "Guard", 0.5, 0.7, guard, 0.2, hilt)
	for _, side in { -1, 1 } do
		add(b, "GuardSpike", Vector3.new(0.14, 0.14, 0.5), CFrame.new(side * guard / 2, 0, 0.85) * CFrame.Angles(0, side * 0.4, 0), hilt)
	end
	local main = bar(b, "Blade", 0.7, 0.7 + length * 0.85, width, 0.1, blade)
	add(b, "BladeTip", Vector3.new(width * 0.55, 0.1, length * 0.2), CFrame.new(0, 0, 0.7 + length * 0.93) * CFrame.Angles(0, 0, 0), blade)
	bar(b, "Glow", 0.8, 0.7 + length * 0.9, width * 0.14, 0.12, glow)
	for i = 1, 3 do
		add(b, "Rune", Vector3.new(width * 0.4, 0.13, 0.12), CFrame.new(0, 0, 0.9 + i * length * 0.18), glow)
	end
	trail(b, main, Vector3.new(0, 0, -length * 0.42), Vector3.new(0, 0, length * 0.42), glow)
end

BUILDERS.Longsword = function(b, glow)
	sword(b, glow, 3.6, 0.36, LOOKS.Obsidian, LOOKS.Iron, 1.2)
end

BUILDERS.Greatsword = function(b, glow)
	sword(b, glow, 4.8, 0.62, LOOKS.Iron, LOOKS.Gold, 1.8)
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = b.Handle
end

BUILDERS.Halberd = function(b, glow)
	bar(b, "Haft", -2.2, 4.4, 0.24, 0.24, LOOKS.DarkIron)
	local blade = add(b, "AxeBlade", Vector3.new(1.4, 0.12, 1.4), CFrame.new(0.72, 0, 4.0), LOOKS.Obsidian)
	add(b, "SpearTip", Vector3.new(0.3, 0.3, 1.3), CFrame.new(0, 0, 5.05) * CFrame.Angles(0, 0, math.pi / 4), LOOKS.Iron)
	add(b, "BackHook", Vector3.new(0.8, 0.12, 0.3), CFrame.new(-0.45, 0, 4.1) * CFrame.Angles(0, -0.5, 0), LOOKS.Iron)
	add(b, "Edge", Vector3.new(0.08, 0.16, 1.5), CFrame.new(1.42, 0, 4.0), glow)
	bar(b, "Wrap", 3.4, 3.7, 0.3, 0.3, glow)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fire.Color = ColorSequence.new(glow)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(0.3, 0)
	fire.Lifetime = NumberRange.new(0.5, 1)
	fire.Speed = NumberRange.new(0.5, 1.5)
	fire.Rate = 12
	fire.Parent = blade
	trail(b, blade, Vector3.new(0.7, 0, -0.7), Vector3.new(0.7, 0, 0.7), glow)
end

BUILDERS.Reaper = function(b, glow)
	add(b, "SkullPommel", Vector3.new(0.5, 0.5, 0.55), CFrame.new(0, 0, -0.75), LOOKS.Bone, Enum.PartType.Ball)
	add(b, "SkullEyes", Vector3.new(0.3, 0.08, 0.08), CFrame.new(0, -0.24, -0.72), glow)
	bar(b, "Guard", 0.5, 0.75, 1.4, 0.24, LOOKS.Obsidian)
	for _, side in { -1, 1 } do
		add(b, "Wing", Vector3.new(0.8, 0.1, 0.3), CFrame.new(side * 0.95, 0, 0.8) * CFrame.Angles(0, side * 0.6, 0), LOOKS.Obsidian)
	end
	-- A long blade that curves like a scythe towards its tip.
	local segments = { { 0.8, 2.4, 0.6, 0 }, { 2.3, 3.8, 0.55, 0.18 }, { 3.7, 5.0, 0.45, 0.42 }, { 4.9, 5.9, 0.32, 0.72 } }
	local first: Part? = nil
	local x = 0
	for index, segment in segments do
		local length = segment[2] - segment[1]
		local angle = segment[4]
		local part = add(b, "Blade", Vector3.new(segment[3], 0.1, length), CFrame.new(x, 0, (segment[1] + segment[2]) / 2) * CFrame.Angles(0, angle, 0), LOOKS.Obsidian)
		add(b, "Edge", Vector3.new(0.09, 0.14, length), CFrame.new(x - segment[3] / 2 * math.cos(angle), 0, (segment[1] + segment[2]) / 2) * CFrame.Angles(0, angle, 0), glow)
		if index == 1 then
			first = part
		end
		x += math.sin(angle) * length * 0.5
	end
	local handleFire = Instance.new("ParticleEmitter")
	handleFire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	handleFire.Color = ColorSequence.new(glow, rgb(40, 0, 10))
	handleFire.LightEmission = 1
	handleFire.Size = NumberSequence.new(0.45, 0)
	handleFire.Lifetime = NumberRange.new(0.6, 1.2)
	handleFire.Speed = NumberRange.new(0.5, 2)
	handleFire.SpreadAngle = Vector2.new(30, 30)
	handleFire.Rate = 20
	handleFire.Parent = first
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 12
	light.Brightness = 2
	light.Parent = b.Handle
	if first then
		trail(b, first, Vector3.new(0, 0, -0.8), Vector3.new(1.2, 0, 4.2), glow)
	end
end

-- Builds a Tool for `def` with the built-in look for its Kind.
function WeaponModels.Build(def: WeaponDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = GRIP

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.1)
	handle.CFrame = CFrame.new()
	handle.Material = Enum.Material.Leather
	handle.Color = rgb(58, 40, 30)
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool

	local glow = def.Glow or Rarities.Get(def.Rarity).Color
	local builder = BUILDERS[def.Kind] or BUILDERS.Longsword
	builder({ Tool = tool, Handle = handle }, glow)
	return tool
end

-- Every weapon kind the catalog uses must have a look.
for _, def in WeaponCatalog.List do
	assert(BUILDERS[def.Kind], `No built-in model for weapon kind "{def.Kind}" ({def.Id})`)
end

return WeaponModels
