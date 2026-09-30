--!strict
-- Toolkit for building rigged, detailed boss models from code.
--
-- Everything is laid out in "rig units": a scale-1 boss is about 6 studs tall,
-- the ground is y = 0 and the boss faces -Z (its right is +X). The kit
-- multiplies positions and sizes by the boss's Scale, so designs are written
-- once and every rarity comes out bigger.
--
-- A model is a HumanoidRootPart plus body segments joined by Motor6Ds
-- (Root, Waist, Neck, LeftShoulder, LeftElbow, LeftHip, LeftKnee…, and extras
-- like Cape1, Tail1, LeftWing, Orbit, Jaw, Float1). Every joint's frame is
-- aligned with the root at rest, which is what the client BossAnimator
-- expects. Details (armor, spikes, runes…) are welded to a segment and move
-- with it. The same rig also works with Roblox's Animation Editor.

local ModelKit = {}
ModelKit.__index = ModelKit

export type Style = {
	Material: Enum.Material?,
	Color: Color3?,
	Transparency: number?,
	Reflectance: number?,
	Variant: string?, -- MaterialVariant to use if MaterialService has one
	CastShadow: boolean?,
}

export type Rig = {
	Hips: BasePart,
	Chest: BasePart,
	Head: BasePart,
	LeftUpperArm: BasePart,
	LeftForearm: BasePart,
	RightUpperArm: BasePart,
	RightForearm: BasePart,
	LeftThigh: BasePart?,
	LeftShin: BasePart?,
	RightThigh: BasePart?,
	RightShin: BasePart?,
	-- Rest positions/frames in rig units.
	P: { [string]: Vector3 },
	F: { [string]: CFrame },
	LegLength: number, -- hip joint height; the Humanoid's HipHeight
	ChestSize: Vector3,
	HeadSize: Vector3,
}

export type Kit = typeof(setmetatable(
	{} :: {
		Def: any,
		Scale: number,
		Model: Model,
		Root: BasePart,
		Random: Random,
		Segments: { [string]: BasePart },
		Joints: { [string]: Motor6D },
		HipHeight: number,
		LegLength: number,
		Lights: number,
	},
	ModelKit
))

local rgb = Color3.fromRGB

local TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local MAX_LIGHTS = 4

-- Material palette. Roblox has no Obsidian or polished-granite material, so
-- they are emulated (glossy dark Glass, reflective Granite). Add a
-- MaterialVariant with the `Variant` name and matching base material to
-- MaterialService to give them custom textures.
ModelKit.Styles = {
	Obsidian = { Material = Enum.Material.Glass, Color = rgb(26, 20, 34), Reflectance = 0.04, Variant = "Obsidian" },
	ObsidianRough = { Material = Enum.Material.Basalt, Color = rgb(30, 26, 36), Variant = "ObsidianRough" },
	PolishedGranite = { Material = Enum.Material.Granite, Color = rgb(108, 106, 112), Reflectance = 0.12, Variant = "PolishedGranite" },
	DarkGranite = { Material = Enum.Material.Granite, Color = rgb(58, 56, 64), Reflectance = 0.1, Variant = "PolishedGranite" },
	Cobblestone = { Material = Enum.Material.Cobblestone, Color = rgb(96, 96, 102) },
	MossyStone = { Material = Enum.Material.Cobblestone, Color = rgb(84, 96, 78) },
	Slate = { Material = Enum.Material.Slate, Color = rgb(70, 72, 80) },
	Metal = { Material = Enum.Material.Metal, Color = rgb(122, 126, 134) },
	DarkMetal = { Material = Enum.Material.Metal, Color = rgb(46, 48, 56) },
	BlackMetal = { Material = Enum.Material.DiamondPlate, Color = rgb(30, 30, 36) },
	Rust = { Material = Enum.Material.CorrodedMetal, Color = rgb(122, 82, 56) },
	Gold = { Material = Enum.Material.Metal, Color = rgb(214, 172, 90), Reflectance = 0.15 },
	DarkGold = { Material = Enum.Material.Metal, Color = rgb(150, 112, 50), Reflectance = 0.1 },
	Bone = { Material = Enum.Material.Limestone, Color = rgb(224, 214, 190) },
	OldBone = { Material = Enum.Material.Limestone, Color = rgb(186, 172, 140) },
	CharredBone = { Material = Enum.Material.Basalt, Color = rgb(40, 32, 30) },
	Cloth = { Material = Enum.Material.Fabric, Color = rgb(38, 30, 36) },
	Burlap = { Material = Enum.Material.Fabric, Color = rgb(120, 92, 60) },
	Leather = { Material = Enum.Material.Leather, Color = rgb(70, 48, 36) },
	Fur = { Material = Enum.Material.Carpet, Color = rgb(62, 46, 38) },
	Wood = { Material = Enum.Material.Wood, Color = rgb(88, 62, 42) },
	DeadWood = { Material = Enum.Material.Wood, Color = rgb(64, 52, 44) },
	Straw = { Material = Enum.Material.Grass, Color = rgb(206, 170, 96) },
	Moss = { Material = Enum.Material.LeafyGrass, Color = rgb(70, 96, 52) },
	Flesh = { Material = Enum.Material.Mud, Color = rgb(112, 122, 96) },
	Ice = { Material = Enum.Material.Ice, Color = rgb(180, 214, 240) },
	Glacier = { Material = Enum.Material.Glacier, Color = rgb(150, 196, 230) },
	Lava = { Material = Enum.Material.CrackedLava, Color = rgb(255, 120, 40) },
	Marble = { Material = Enum.Material.Marble, Color = rgb(236, 232, 224) },
	Hidden = { Material = Enum.Material.SmoothPlastic, Color = rgb(0, 0, 0), Transparency = 1, CastShadow = false },
} :: { [string]: Style }

function ModelKit.Neon(color: Color3, transparency: number?): Style
	return { Material = Enum.Material.Neon, Color = color, Transparency = transparency, CastShadow = false }
end

-- Shimmering, see-through spectral surface.
function ModelKit.Ghost(color: Color3, transparency: number?): Style
	return { Material = Enum.Material.ForceField, Color = color, Transparency = transparency or 0.2, CastShadow = false }
end

-- Copy of a named style (or style table) with overrides.
function ModelKit.Tint(style: Style | string, overrides: { [string]: any }): Style
	local base = if type(style) == "string" then ModelKit.Styles[style] else style
	assert(base, `Unknown style "{tostring(style)}"`)
	local copy = table.clone(base) :: any
	for key, value in overrides do
		copy[key] = value
	end
	return copy
end

local function seedFrom(text: string): number
	local seed = 7
	for i = 1, #text do
		seed = (seed * 31 + string.byte(text, i)) % 2147483647
	end
	return seed
end

local function getMaterialService(): Instance?
	local ok, service = pcall(function()
		return game:GetService("MaterialService")
	end)
	return if ok then service else nil
end

-- CFrame at `at` looking toward `target` (-Z points at it). Built with
-- fromMatrix so vertical directions are handled, and so it behaves the same
-- outside Roblox (tests, previews).
function ModelKit.LookAt(at: Vector3, target: Vector3): CFrame
	local direction = target - at
	if direction.Magnitude < 1e-4 then
		return CFrame.new(at)
	end
	local forward = direction.Unit
	local hint = if math.abs(forward.Y) > 0.99 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local right = forward:Cross(hint).Unit
	local up = right:Cross(forward).Unit
	return CFrame.fromMatrix(at, right, up, -forward)
end

-- CFrame at the midpoint of a→b whose -Z axis points from a to b.
function ModelKit.Along(a: Vector3, b: Vector3): CFrame
	return ModelKit.LookAt((a + b) / 2, b + (b - a))
end

-- Rotates `vector` by `angle` radians around `axis`.
function ModelKit.Rotate(vector: Vector3, axis: Vector3, angle: number): Vector3
	return CFrame.fromAxisAngle(axis.Unit, angle):VectorToWorldSpace(vector)
end

function ModelKit.new(def: any, scale: number): Kit
	local model = Instance.new("Model")
	model.Name = def.Name

	local self = setmetatable({
		Def = def,
		Scale = scale,
		Model = model,
		Root = nil :: any,
		Random = Random.new(seedFrom(def.Id)),
		Segments = {},
		Joints = {},
		HipHeight = 2,
		LegLength = 2,
		Lights = 0,
	}, ModelKit)
	return self
end

-- Randomness that is the same every time this boss is built.
function ModelKit.Rand(self: Kit, min: number, max: number): number
	return self.Random:NextNumber(min, max)
end

function ModelKit.ApplyStyle(self: Kit, part: BasePart, style: Style)
	part.Material = style.Material or Enum.Material.SmoothPlastic
	part.Color = style.Color or Color3.new(0.5, 0.5, 0.5)
	part.Transparency = style.Transparency or 0
	part.Reflectance = style.Reflectance or 0
	if style.Variant then
		local service = getMaterialService()
		local variant = service and service:FindFirstChild(style.Variant)
		if variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == part.Material then
			part.MaterialVariant = style.Variant
		end
	end
	if style.CastShadow == false or part.Transparency >= 0.5 then
		part.CastShadow = false
	end
end

-- Converts a rig-space CFrame to model space (scales the position only).
function ModelKit.ToModel(self: Kit, cf: CFrame): CFrame
	return CFrame.new(cf.Position * self.Scale) * cf.Rotation
end

local function resolveStyle(style: Style | string): Style
	if type(style) == "string" then
		local named = ModelKit.Styles[style]
		assert(named, `Unknown style "{style}"`)
		return named
	end
	return style
end

function ModelKit.NewPart(self: Kit, name: string, size: Vector3, cf: CFrame, style: Style | string, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size * self.Scale
	part.CFrame = self:ToModel(cf)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	self:ApplyStyle(part, resolveStyle(style))
	if math.max(size.X, size.Y, size.Z) < 0.35 then
		part.CastShadow = false
	end
	part.Parent = self.Model
	return part
end

local function segmentOf(self: Kit, parent: BasePart | string): BasePart
	if type(parent) == "string" then
		local segment = self.Segments[parent]
		assert(segment, `Unknown segment "{parent}"`)
		return segment
	end
	return parent
end

-- A detail welded to `parent` (a segment name or part).
function ModelKit.Part(self: Kit, parent: BasePart | string, size: Vector3, cf: CFrame, style: Style | string, shape: Enum.PartType?, name: string?): Part
	local segment = segmentOf(self, parent)
	local part = self:NewPart(name or "Detail", size, cf, style, shape)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = segment
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- A body segment joined to `parent` by a Motor6D named `jointName` at `pivot`.
function ModelKit.Segment(
	self: Kit,
	name: string,
	parent: BasePart | string,
	jointName: string,
	pivot: Vector3,
	size: Vector3,
	cf: CFrame,
	style: Style | string,
	shape: Enum.PartType?
): Part
	local parentPart = segmentOf(self, parent)
	local part = self:NewPart(name, size, cf, style, shape)
	local pivotCFrame = CFrame.new(pivot * self.Scale)
	local joint = Instance.new("Motor6D")
	joint.Name = jointName
	joint.Part0 = parentPart
	joint.Part1 = part
	joint.C0 = parentPart.CFrame:Inverse() * pivotCFrame
	joint.C1 = part.CFrame:Inverse() * pivotCFrame
	joint.Parent = part
	self.Segments[name] = part
	self.Joints[jointName] = joint
	return part
end

-- Shapes ------------------------------------------------------------------------

function ModelKit.Ball(self: Kit, parent: BasePart | string, diameter: number | Vector3, position: Vector3 | CFrame, style: Style | string): Part
	local size = if type(diameter) == "number" then Vector3.one * diameter else diameter
	local cf = if typeof(position) == "CFrame" then position else CFrame.new(position :: Vector3)
	return self:Part(parent, size, cf, style, Enum.PartType.Ball, "Orb")
end

-- A stretched sphere (SpecialMesh) filling `size`: bellies, pumpkins, skulls.
function ModelKit.Ellipsoid(self: Kit, parent: BasePart | string, size: Vector3, cf: CFrame | Vector3, style: Style | string): Part
	local placement = if typeof(cf) == "CFrame" then cf else CFrame.new(cf :: Vector3)
	local part = self:Part(parent, size, placement, style, nil, "Ellipsoid")
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A straight bar from `a` to `b`.
function ModelKit.Rod(self: Kit, parent: BasePart | string, a: Vector3, b: Vector3, thickness: number | Vector2, style: Style | string, round: boolean?): Part
	local length = (b - a).Magnitude
	local t = if type(thickness) == "number" then Vector2.new(thickness, thickness) else thickness
	if round then
		return self:Part(parent, Vector3.new(length, t.Y, t.X), ModelKit.Along(a, b) * CFrame.Angles(0, math.pi / 2, 0), style, Enum.PartType.Cylinder, "Rod")
	end
	return self:Part(parent, Vector3.new(t.X, t.Y, length), ModelKit.Along(a, b), style, nil, "Rod")
end

-- A tapering spike, claw or tooth from `base` to `tip`.
function ModelKit.Spike(self: Kit, parent: BasePart | string, base: Vector3, tip: Vector3, thickness: number, style: Style | string, segments: number?)
	local count = segments or 2
	for i = 1, count do
		local a = base:Lerp(tip, (i - 1) / count)
		local b = base:Lerp(tip, i / count)
		local t = thickness * (1 - (i - 1) / count * 0.8)
		self:Part(parent, Vector3.new(t, t, (b - a).Magnitude * 1.08), ModelKit.Along(a, b) * CFrame.Angles(0, 0, math.pi / 4), style, nil, "Spike")
	end
end

-- A curved horn: starts at `base` heading `direction`, bending `curl` radians
-- around `bendAxis` over its length.
function ModelKit.Horn(
	self: Kit,
	parent: BasePart | string,
	base: Vector3,
	direction: Vector3,
	length: number,
	thickness: number,
	curl: number,
	bendAxis: Vector3,
	style: Style | string,
	segments: number?
)
	local count = segments or 5
	local step = length / count
	local point = base
	local heading = direction.Unit
	for i = 1, count do
		local nextPoint = point + heading * step
		local t = thickness * (1 - (i - 1) / count * 0.85)
		self:Part(parent, Vector3.new(t, t, step * 1.12), ModelKit.Along(point, nextPoint), style, nil, "Horn")
		point = nextPoint
		heading = ModelKit.Rotate(heading, bendAxis, curl / count)
	end
end

-- `count` copies of `size` around a circle in `cf`'s XZ plane.
function ModelKit.Ring(self: Kit, parent: BasePart | string, cf: CFrame, radius: number, count: number, size: Vector3, style: Style | string, shape: Enum.PartType?)
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		local placement = cf * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
		self:Part(parent, size, placement, style, shape, "RingPiece")
	end
end

-- Points or spikes around a circle, pointing outward/up (crowns, collars).
function ModelKit.Crown(self: Kit, parent: BasePart | string, cf: CFrame, radius: number, count: number, height: number, thickness: number, style: Style | string, outward: number?)
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		local base = (cf * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)).Position
		local out = (cf:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle)))) * (outward or 0.15)
		local tip = base + cf.UpVector * height * (if i % 2 == 0 then 1 else 0.7) + out * height
		self:Spike(parent, base, tip, thickness, style)
	end
end

-- Glowing runes laid on a surface. `cf` sits on the surface with -Z pointing
-- out of it.
local GLYPHS = {
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.1, -0.35, 0.5 }, { 0, 0.1, 0.35, 0.5 } },
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.5, 0.35, 0.15 }, { 0.35, 0.15, 0, -0.15 } },
	{ { -0.3, -0.5, 0.3, 0.5 }, { 0.3, -0.5, -0.3, 0.5 } },
	{ { 0, -0.5, 0, 0.5 }, { -0.35, 0.2, 0, 0.5 }, { 0.35, 0.2, 0, 0.5 } },
	{ { -0.3, 0.5, 0.3, 0.15 }, { 0.3, 0.15, -0.3, -0.15 }, { -0.3, -0.15, 0.3, -0.5 } },
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.45, 0.35, 0.1 }, { 0, 0.05, 0.35, -0.3 } },
	{ { 0, 0.5, -0.35, 0 }, { -0.35, 0, 0, -0.5 }, { 0, -0.5, 0.35, 0 }, { 0.35, 0, 0, 0.5 } },
}

function ModelKit.Runes(self: Kit, parent: BasePart | string, cf: CFrame, width: number, height: number, count: number, color: Color3)
	local cell = width / count
	local stroke = math.max(0.035, cell * 0.12)
	local style = ModelKit.Neon(color)
	for i = 1, count do
		local glyph = GLYPHS[self.Random:NextInteger(1, #GLYPHS)]
		local center = cf * CFrame.new(-width / 2 + cell * (i - 0.5), 0, -0.02)
		for _, bar in glyph do
			local a = (center * CFrame.new(bar[1] * cell * 0.8, bar[2] * height, 0)).Position
			local b = (center * CFrame.new(bar[3] * cell * 0.8, bar[4] * height, 0)).Position
			local rod = self:Rod(parent, a, b, Vector2.new(stroke, stroke * 0.5), style)
			rod.Name = "Rune"
		end
	end
end

-- Curved ribs around a chest centre (exposed skeletons).
function ModelKit.Ribcage(self: Kit, parent: BasePart | string, center: CFrame, width: number, height: number, depth: number, count: number, style: Style | string, thickness: number?)
	local t = thickness or 0.09
	for i = 0, count - 1 do
		local y = height / 2 - (i + 0.5) * height / count
		local shrink = 1 - (i / count) * 0.35
		for _, side in { -1, 1 } do
			local spine = (center * CFrame.new(0, y, depth / 2)).Position
			local flank = (center * CFrame.new(side * width / 2 * shrink, y - 0.08, depth * 0.05)).Position
			local front = (center * CFrame.new(side * width * 0.16, y - 0.2, -depth / 2)).Position
			self:Rod(parent, spine, flank, t, style)
			self:Rod(parent, flank, front, t, style)
		end
	end
	-- Sternum and spine.
	self:Rod(parent, (center * CFrame.new(0, height / 2, -depth / 2)).Position, (center * CFrame.new(0, -height * 0.25, -depth / 2)).Position, t * 1.4, style)
	for i = 0, count do
		local y = height / 2 - i * height / count
		self:Part(parent, Vector3.new(t * 2.4, t * 1.6, t * 2.4), center * CFrame.new(0, y, depth / 2), style, nil, "Vertebra")
	end
end

-- A chain of alternating links from `a` to `b`.
function ModelKit.Chain(self: Kit, parent: BasePart | string, a: Vector3, b: Vector3, link: number, style: Style | string)
	local length = (b - a).Magnitude
	local count = math.max(2, math.floor(length / (link * 0.8)))
	local base = ModelKit.Along(a, b)
	for i = 0, count - 1 do
		local center = a:Lerp(b, (i + 0.5) / count)
		local twist = if i % 2 == 0 then 0 else math.pi / 2
		self:Part(parent, Vector3.new(link * 0.18, link * 0.5, link), CFrame.new(center) * base.Rotation * CFrame.Angles(0, 0, twist), style, nil, "ChainLink")
	end
end

-- Ragged cloth strips hanging from the line a→b (keep a→b horizontal).
-- With a→b running left to right, a positive `backLean` swings the bottoms
-- backwards (+Z).
function ModelKit.Strips(self: Kit, parent: BasePart | string, a: Vector3, b: Vector3, count: number, minLength: number, maxLength: number, thickness: number, style: Style | string, backLean: number?)
	local width = (b - a).Magnitude / count
	local lean = backLean or 0
	-- X along a→b, Y up.
	local rotation = ModelKit.Along(a, b).Rotation * CFrame.Angles(0, math.pi / 2, 0)
	for i = 0, count - 1 do
		local top = a:Lerp(b, (i + 0.5) / count)
		local length = self:Rand(minLength, maxLength)
		local tilt = self:Rand(-0.08, 0.08)
		local cf = CFrame.new(top) * rotation * CFrame.Angles(-lean, 0, tilt) * CFrame.new(0, -length / 2, 0)
		self:Part(parent, Vector3.new(width * self:Rand(0.75, 1.05), length, thickness), cf, style, nil, "Strip")
	end
end

-- Glowing eyes on a face. `cf` is the face centre, -Z pointing out.
function ModelKit.Eyes(self: Kit, parent: BasePart | string, cf: CFrame, spacing: number, size: Vector3, color: Color3, withLight: boolean?): { Part }
	local eyes = {}
	for _, side in { -1, 1 } do
		local eye = self:Part(parent, size, cf * CFrame.new(side * spacing / 2, 0, 0) * CFrame.Angles(0, 0, side * 0.18), ModelKit.Neon(color), nil, "Eye")
		table.insert(eyes, eye)
		self:Emit(eye, "Wisps", color, { Rate = 4, Size = 0.18, Speed = 0.3, Lifetime = 0.8 })
	end
	if withLight ~= false then
		self:Light(eyes[1], color, 5, 2)
	end
	return eyes
end

-- A row of spikes between two points, all pointing along `direction`.
function ModelKit.SpikeRow(self: Kit, parent: BasePart | string, from: Vector3, to: Vector3, count: number, length: number, direction: Vector3, thickness: number, style: Style | string)
	for i = 0, count - 1 do
		local t = if count == 1 then 0.5 else i / (count - 1)
		local base = from:Lerp(to, t)
		-- Longest in the middle of the row.
		local scale = 0.6 + 0.4 * math.sin(t * math.pi)
		self:Spike(parent, base, base + direction.Unit * length * scale, thickness * scale, style)
	end
end

-- An armor plate with trimmed edges and optional runes on its front (-Z) face.
function ModelKit.Plate(self: Kit, parent: BasePart | string, size: Vector3, cf: CFrame, style: Style | string, trim: (Style | string)?, runeColor: Color3?, runeCount: number?): Part
	local plate = self:Part(parent, size, cf, style, nil, "Plate")
	if trim then
		for _, sign in { -1, 1 } do
			self:Part(parent, Vector3.new(size.X + 0.04, math.min(0.1, size.Y * 0.15), size.Z + 0.04), cf * CFrame.new(0, sign * (size.Y / 2 - 0.03), 0), trim, nil, "Trim")
		end
	end
	if runeColor then
		self:Runes(parent, cf * CFrame.new(0, 0, -size.Z / 2), size.X * 0.7, size.Y * 0.35, runeCount or 3, runeColor)
	end
	return plate
end

-- A flared robe or skirt: panels around a ring from `top` (radius
-- `topRadius`) down to `bottomRadius`, with a ragged hem.
function ModelKit.Robe(self: Kit, parent: BasePart | string, top: Vector3, topRadius: number, bottomRadius: number, length: number, panels: number, style: Style | string, depth: number?, tatters: boolean?)
	local d = depth or 0.75
	local panelWidth = math.pi * (topRadius + bottomRadius) / panels * 1.2
	for i = 0, panels - 1 do
		local angle = (i + 0.5) / panels * math.pi * 2
		local c, sn = math.cos(angle), math.sin(angle)
		local a = top + Vector3.new(c * topRadius, 0, sn * topRadius * d)
		local drop = length * self:Rand(0.88, 1.08)
		local b = top + Vector3.new(c * bottomRadius, -drop, sn * bottomRadius * d)
		local up = (a - b).Unit
		local tangent = Vector3.new(-sn, 0, c)
		local normal = tangent:Cross(up).Unit
		tangent = up:Cross(normal).Unit
		self:Part(parent, Vector3.new(panelWidth, (a - b).Magnitude, 0.07), CFrame.fromMatrix((a + b) / 2, tangent, up, normal), style, nil, "RobePanel")
		if tatters ~= false and i % 2 == 0 then
			local hem = b - up * 0.02
			local strip = length * self:Rand(0.12, 0.3)
			self:Part(parent, Vector3.new(panelWidth * 0.45, strip, 0.05), CFrame.fromMatrix(hem - up * strip / 2, tangent, up, normal), style, nil, "RobeTatter")
		end
	end
end

-- Long strands hanging from the back half of a ring (hair, manes, veils).
function ModelKit.Hair(self: Kit, parent: BasePart | string, center: CFrame, radius: number, count: number, length: number, width: number, style: Style | string, sweep: number?)
	for i = 0, count - 1 do
		local angle = math.pi * (0.05 + 0.9 * i / math.max(1, count - 1))
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = (center * CFrame.new(out * radius)).Position
		local strandLength = length * self:Rand(0.75, 1.15)
		local direction = (Vector3.new(0, -1, 0) + center:VectorToWorldSpace(out) * 0.25 + Vector3.new(0, 0, sweep or 0.35)).Unit
		local tip = base + direction * strandLength
		self:Part(parent, Vector3.new(width, width * 0.35, strandLength), ModelKit.Along(base, tip), style, nil, "Strand")
	end
end

-- Effects -----------------------------------------------------------------------

function ModelKit.Light(self: Kit, part: BasePart, color: Color3, range: number, brightness: number?): PointLight?
	if self.Lights >= MAX_LIGHTS then
		return nil
	end
	self.Lights += 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range * self.Scale, 60)
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = part
	return light
end

type EmitOptions = {
	Rate: number?,
	Size: number?,
	Speed: number?,
	Lifetime: number?,
	Offset: Vector3?,
	Transparency: number?,
	Name: string?,
}

local PRESETS: { [string]: { [string]: any } } = {
	Wisps = { Texture = "Sparkle", Size = 0.35, EndSize = 0, Rate = 8, Lifetime = 1.4, Speed = 0.8, Spread = 35, Rise = 0.8, Light = 1, Alpha = 0.15 },
	Smoke = { Texture = "Smoke", Size = 1.4, EndSize = 3, Rate = 6, Lifetime = 3, Speed = 0.5, Spread = 60, Rise = 0.4, Light = 0, Alpha = 0.55, Spin = 20 },
	Mist = { Texture = "Smoke", Size = 2.4, EndSize = 4.5, Rate = 5, Lifetime = 4, Speed = 0.4, Spread = 180, Rise = 0.05, Light = 0, Alpha = 0.72, Spin = 10 },
	Embers = { Texture = "Sparkle", Size = 0.25, EndSize = 0, Rate = 14, Lifetime = 1.6, Speed = 1.6, Spread = 45, Rise = 2.5, Light = 1, Alpha = 0 },
	Flames = { Texture = "Fire", Size = 1.2, EndSize = 0.2, Rate = 28, Lifetime = 0.8, Speed = 1.6, Spread = 20, Rise = 3.2, Light = 1, Alpha = 0.1, Spin = 40 },
	Frost = { Texture = "Sparkle", Size = 0.25, EndSize = 0.05, Rate = 10, Lifetime = 2.4, Speed = 0.4, Spread = 180, Rise = -0.6, Light = 0.8, Alpha = 0.1 },
	Void = { Texture = "Smoke", Size = 1.6, EndSize = 3, Rate = 8, Lifetime = 2.6, Speed = 0.6, Spread = 180, Rise = 0.2, Light = 0.25, Alpha = 0.45, Spin = 30 },
	Spectral = { Texture = "Sparkle", Size = 0.5, EndSize = 0, Rate = 12, Lifetime = 1.8, Speed = 1.2, Spread = 180, Rise = 0.3, Light = 1, Alpha = 0.2, Spin = 120 },
	Drips = { Texture = "Sparkle", Size = 0.16, EndSize = 0.1, Rate = 5, Lifetime = 0.9, Speed = 0.1, Spread = 10, Rise = -9, Light = 0.6, Alpha = 0 },
	Flies = { Texture = "Sparkle", Size = 0.12, EndSize = 0.12, Rate = 12, Lifetime = 1.5, Speed = 1.6, Spread = 180, Rise = 0, Light = 0, Alpha = 0 },
	Bubbles = { Texture = "Sparkle", Size = 0.2, EndSize = 0.35, Rate = 6, Lifetime = 2, Speed = 0.4, Spread = 50, Rise = 1.5, Light = 0.7, Alpha = 0.3 },
}

-- Adds a particle effect from a preset (sizes scale with the boss).
function ModelKit.Emit(self: Kit, part: BasePart, presetName: string, color: Color3, options: EmitOptions?): ParticleEmitter
	local preset = PRESETS[presetName]
	assert(preset, `Unknown emitter preset "{presetName}"`)
	local o: EmitOptions = options or {}
	local s = self.Scale
	local size = (o.Size or preset.Size) * s
	local endSize = (if o.Size then o.Size * (preset.EndSize / preset.Size) else preset.EndSize) * s

	local parentInstance: Instance = part
	if o.Offset then
		local attachment = Instance.new("Attachment")
		attachment.Name = "EmitterAttachment"
		attachment.Position = o.Offset * s
		attachment.Parent = part
		parentInstance = attachment
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = o.Name or presetName
	emitter.Texture = TEXTURES[preset.Texture]
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.5))
	emitter.LightEmission = preset.Light
	emitter.LightInfluence = if preset.Light > 0 then 0 else 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, endSize),
	})
	local alpha = o.Transparency or preset.Alpha
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, alpha),
		NumberSequenceKeypoint.new(1, 1),
	})
	local lifetime = o.Lifetime or preset.Lifetime
	emitter.Lifetime = NumberRange.new(lifetime * 0.7, lifetime * 1.3)
	local speed = (o.Speed or preset.Speed) * math.sqrt(s)
	emitter.Speed = NumberRange.new(speed * 0.6, speed * 1.4)
	emitter.SpreadAngle = Vector2.new(preset.Spread, preset.Spread)
	emitter.Acceleration = Vector3.new(0, preset.Rise * math.sqrt(s), 0)
	emitter.Rate = o.Rate or preset.Rate
	emitter.Rotation = NumberRange.new(0, 360)
	if preset.Spin then
		emitter.RotSpeed = NumberRange.new(-preset.Spin, preset.Spin)
	end
	emitter.Parent = parentInstance
	return emitter
end

function ModelKit.Fire(self: Kit, part: BasePart, color: Color3, secondary: Color3, size: number, heat: number?): Fire
	local fire = Instance.new("Fire")
	fire.Color = color
	fire.SecondaryColor = secondary
	fire.Size = math.clamp(size * self.Scale, 2, 30)
	fire.Heat = math.clamp((heat or 9) * math.sqrt(self.Scale), 0, 25)
	fire.Parent = part
	return fire
end

-- A light trail between two points on a part (rig units, relative to the part).
function ModelKit.Trail(self: Kit, part: BasePart, a: Vector3, b: Vector3, color: Color3, lifetime: number?): Trail
	local s = self.Scale
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailStart"
	a0.Position = a * s
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailEnd"
	a1.Position = b * s
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = lifetime or 0.35
	trail.MinLength = 0.05
	trail.FaceCamera = false
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = part
	return trail
end

-- Body rig ----------------------------------------------------------------------

-- `Round = true` on a body group hides the box segment and covers it with an
-- ellipsoid instead (organic creatures); `Fat` scales that ellipsoid.
export type RigOptions = {
	-- Gap shrinks limb segments (0-1) so they float apart (spectral armor).
	Legs: { Thigh: number, Shin: number, Spacing: number, Width: number, Style: Style | string, ShinStyle: (Style | string)?, Gap: number?, Round: boolean?, Fat: number? }?,
	Hover: number?, -- hip height when there are no legs
	Hips: { Size: Vector3, Style: Style | string, Round: boolean?, Fat: number? },
	Chest: { Size: Vector3, Style: Style | string, Lean: number?, Round: boolean?, Fat: number? },
	Arms: { Upper: number, Fore: number, Width: number, ShoulderX: number, Drop: number?, Style: Style | string, ForeStyle: (Style | string)?, Gap: number?, Round: boolean?, Fat: number? },
	Head: { Size: Vector3, Style: Style | string, Shape: Enum.PartType?, Neck: number?, Tilt: number?, Round: boolean?, Fat: number? },
}

-- Hides a segment and wraps it in an ellipsoid of the same style.
local function roundOff(self: Kit, segment: BasePart, style: Style | string, fat: number?)
	local f = fat or 1.12
	local size = segment.Size / self.Scale
	local rigCFrame = CFrame.new(segment.CFrame.Position / self.Scale) * segment.CFrame.Rotation
	self:Ellipsoid(segment, Vector3.new(size.X * f, size.Y * (1 + (f - 1) * 0.5), size.Z * f), rigCFrame, style)
	segment.Transparency = 1
	segment.CastShadow = false
end

-- Builds the root, core body segments and joints. Returns rest positions (P)
-- and frames (F) so a design can place details.
function ModelKit.Rig(self: Kit, options: RigOptions): Rig
	local legs = options.Legs
	local legLength = if legs then legs.Thigh + legs.Shin else (options.Hover or 3)
	self.LegLength = legLength
	self.HipHeight = legLength

	local chestSize = options.Chest.Size
	local hipsSize = options.Hips.Size

	-- Root: invisible physics box whose bottom sits at HipHeight.
	local rootSize = Vector3.new(math.max(2, chestSize.X * 0.8), 2, math.max(1, chestSize.Z * 0.8))
	local root = self:NewPart("HumanoidRootPart", rootSize, CFrame.new(0, legLength + 1, 0), "Hidden")
	root.CanCollide = true
	root.Massless = false
	self.Root = root
	self.Segments.HumanoidRootPart = root
	self.Model.PrimaryPart = root

	local P: { [string]: Vector3 } = {}
	local F: { [string]: CFrame } = {}

	-- Hips and chest.
	P.Pelvis = Vector3.new(0, legLength + hipsSize.Y / 2, 0)
	local hips = self:Segment("Hips", root, "Root", P.Pelvis, hipsSize, CFrame.new(P.Pelvis), options.Hips.Style)
	F.Hips = CFrame.new(P.Pelvis)
	if options.Hips.Round then
		roundOff(self, hips, options.Hips.Style, options.Hips.Fat)
	end

	P.Waist = Vector3.new(0, legLength + hipsSize.Y, 0)
	local lean = options.Chest.Lean or 0
	local chestCF = CFrame.new(P.Waist) * CFrame.Angles(-lean, 0, 0) * CFrame.new(0, chestSize.Y / 2, 0)
	local chest = self:Segment("Chest", hips, "Waist", P.Waist, chestSize, chestCF, options.Chest.Style)
	F.Chest = chestCF
	if options.Chest.Round then
		roundOff(self, chest, options.Chest.Style, options.Chest.Fat)
	end
	P.ChestTop = (chestCF * CFrame.new(0, chestSize.Y / 2, 0)).Position
	P.Back = (chestCF * CFrame.new(0, chestSize.Y * 0.25, chestSize.Z / 2)).Position

	-- Head.
	local headOptions = options.Head
	local neckLength = headOptions.Neck or 0.15
	P.Neck = P.ChestTop
	local headCF = CFrame.new(P.Neck) * CFrame.Angles(-lean * 0.35 + (headOptions.Tilt or 0), 0, 0)
		* CFrame.new(0, neckLength + headOptions.Size.Y / 2, 0)
	if lean > 0 then
		-- Hunched bodies carry the head forward.
		headCF = CFrame.new(0, 0, -headOptions.Size.Z * 0.25 * math.min(lean, 1)) * headCF
	end
	local head = self:Segment("Head", chest, "Neck", P.Neck, headOptions.Size, headCF, headOptions.Style, headOptions.Shape)
	F.Head = headCF
	if headOptions.Round then
		roundOff(self, head, headOptions.Style, headOptions.Fat)
	end

	-- Arms hang straight down from the shoulders at rest.
	local arms = options.Arms
	local drop = arms.Drop or 0.3
	local armFill = 1 - (arms.Gap or 0)
	local rigParts: { [string]: BasePart } = {}
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder = (chestCF * CFrame.new(side * arms.ShoulderX, chestSize.Y / 2 - drop, 0)).Position
		local elbow = shoulder - Vector3.new(0, arms.Upper, 0)
		local hand = elbow - Vector3.new(0, arms.Fore, 0)
		P[prefix .. "Shoulder"] = shoulder
		P[prefix .. "Elbow"] = elbow
		P[prefix .. "Hand"] = hand
		rigParts[prefix .. "UpperArm"] = self:Segment(
			prefix .. "UpperArm",
			chest,
			prefix .. "Shoulder",
			shoulder,
			Vector3.new(arms.Width, arms.Upper * armFill, arms.Width),
			CFrame.new(shoulder - Vector3.new(0, arms.Upper / 2, 0)),
			arms.Style
		)
		rigParts[prefix .. "Forearm"] = self:Segment(
			prefix .. "Forearm",
			prefix .. "UpperArm",
			prefix .. "Elbow",
			elbow,
			Vector3.new(arms.Width * 0.9, arms.Fore * armFill, arms.Width * 0.9),
			CFrame.new(elbow - Vector3.new(0, arms.Fore / 2, 0)),
			arms.ForeStyle or arms.Style
		)
		if arms.Round then
			roundOff(self, rigParts[prefix .. "UpperArm"], arms.Style, arms.Fat)
			roundOff(self, rigParts[prefix .. "Forearm"], arms.ForeStyle or arms.Style, arms.Fat)
		end
	end

	-- Legs.
	if legs then
		local legFill = 1 - (legs.Gap or 0)
		for _, side in { -1, 1 } do
			local prefix = if side < 0 then "Left" else "Right"
			local hip = Vector3.new(side * legs.Spacing, legLength, 0)
			local knee = hip - Vector3.new(0, legs.Thigh, 0)
			local foot = Vector3.new(side * legs.Spacing, 0, 0)
			P[prefix .. "Hip"] = hip
			P[prefix .. "Knee"] = knee
			P[prefix .. "Foot"] = foot
			rigParts[prefix .. "Thigh"] = self:Segment(
				prefix .. "Thigh",
				hips,
				prefix .. "Hip",
				hip,
				Vector3.new(legs.Width, legs.Thigh * legFill, legs.Width),
				CFrame.new(hip - Vector3.new(0, legs.Thigh / 2, 0)),
				legs.Style
			)
			rigParts[prefix .. "Shin"] = self:Segment(
				prefix .. "Shin",
				prefix .. "Thigh",
				prefix .. "Knee",
				knee,
				Vector3.new(legs.Width * 0.9, legs.Shin * legFill, legs.Width * 0.9),
				CFrame.new(knee - Vector3.new(0, legs.Shin / 2, 0)),
				legs.ShinStyle or legs.Style
			)
			if legs.Round then
				roundOff(self, rigParts[prefix .. "Thigh"], legs.Style, legs.Fat)
				roundOff(self, rigParts[prefix .. "Shin"], legs.ShinStyle or legs.Style, legs.Fat)
			end
		end
	end

	return {
		Hips = hips,
		Chest = chest,
		Head = head,
		LeftUpperArm = rigParts.LeftUpperArm,
		LeftForearm = rigParts.LeftForearm,
		RightUpperArm = rigParts.RightUpperArm,
		RightForearm = rigParts.RightForearm,
		LeftThigh = rigParts.LeftThigh,
		LeftShin = rigParts.LeftShin,
		RightThigh = rigParts.RightThigh,
		RightShin = rigParts.RightShin,
		P = P,
		F = F,
		LegLength = legLength,
		ChestSize = chestSize,
		HeadSize = headOptions.Size,
	}
end

-- Composite parts -----------------------------------------------------------------

-- A jointed cape hanging from `top` (centre of its top edge): bands named
-- CapeBand1..n with joints Cape1..n, plus a tattered hem.
function ModelKit.Cape(
	self: Kit,
	parent: BasePart | string,
	top: Vector3,
	width: number,
	length: number,
	bands: number,
	style: Style | string,
	trim: (Style | string)?,
	tatters: boolean?
)
	local bandLength = length / bands
	local previous: BasePart | string = parent
	local y = top.Y
	for i = 1, bands do
		local bandWidth = width * (1 + (i - 1) * 0.12)
		local pivot = Vector3.new(top.X, y, top.Z + (i - 1) * 0.06)
		local center = pivot - Vector3.new(0, bandLength / 2, -0.03)
		local band = self:Segment(`CapeBand{i}`, previous, `Cape{i}`, pivot, Vector3.new(bandWidth, bandLength * 1.04, 0.08), CFrame.new(center), style)
		if trim and i == 1 then
			self:Part(band, Vector3.new(bandWidth + 0.1, 0.16, 0.14), CFrame.new(pivot - Vector3.new(0, 0.05, 0)), trim)
		end
		if i == bands and tatters ~= false then
			local bottom = pivot - Vector3.new(0, bandLength, 0)
			self:Strips(band, bottom - Vector3.new(bandWidth / 2, 0, 0), bottom + Vector3.new(bandWidth / 2, 0, 0), 7, bandLength * 0.2, bandLength * 0.9, 0.07, style)
		end
		previous = band
		y -= bandLength
	end
end

-- A chain of jointed segments (tails, tentacles): joints `prefix`1..n.
function ModelKit.Tail(
	self: Kit,
	parent: BasePart | string,
	prefix: string,
	base: Vector3,
	direction: Vector3,
	length: number,
	thickness: number,
	segments: number,
	style: Style | string,
	curl: number?,
	bendAxis: Vector3?,
	decorate: ((segment: BasePart, a: Vector3, b: Vector3, index: number) -> ())?
): { BasePart }
	local step = length / segments
	local heading = direction.Unit
	local point = base
	local previous: BasePart | string = parent
	local parts: { BasePart } = {}
	for i = 1, segments do
		local nextPoint = point + heading * step
		local t = thickness * (1 - (i - 1) / segments * 0.7)
		local segment = self:Segment(`{prefix}Segment{i}`, previous, `{prefix}{i}`, point, Vector3.new(t, t, step * 1.1), ModelKit.Along(point, nextPoint), style)
		if decorate then
			decorate(segment, point, nextPoint, i)
		end
		table.insert(parts, segment)
		previous = segment
		point = nextPoint
		if curl and bendAxis then
			heading = ModelKit.Rotate(heading, bendAxis, curl / segments)
		end
	end
	return parts
end

-- A wing jointed at `root` (LeftWing/RightWing). `side` is -1 (left) or 1.
-- `kind` is "Bone" (bat-like membrane), "Feather" or "Torn".
-- `pair` numbers extra pairs (LeftWing2, RightWing2…) for many-winged bosses.
function ModelKit.Wing(self: Kit, parent: BasePart | string, side: number, root: Vector3, span: number, height: number, kind: string, boneStyle: Style | string, skinStyle: Style | string, pair: number?): BasePart
	local name = (if side < 0 then "LeftWing" else "RightWing") .. (if pair and pair > 1 then tostring(pair) else "")
	local wing = self:Segment(name, parent, name, root, Vector3.new(0.2, 0.2, 0.2), CFrame.new(root), "Hidden")
	local outward = Vector3.new(side, 0, 0)
	-- Main arm of the wing: up and out, then down to the tip.
	local elbow = root + outward * span * 0.45 + Vector3.new(0, height * 0.55, 0.35)
	local tip = root + outward * span + Vector3.new(0, height * 0.25, 0.8)
	self:Rod(wing, root, elbow, 0.16, boneStyle)
	self:Rod(wing, elbow, tip, 0.12, boneStyle)
	self:Spike(wing, tip, tip + outward * 0.5 + Vector3.new(0, 0.35, 0), 0.12, boneStyle)

	if kind == "Feather" then
		-- Layered feather blades fanning down from the wing arm, flat along the span.
		local count = 9
		for i = 0, count - 1 do
			local t = i / (count - 1)
			local anchor = if t < 0.45 then root:Lerp(elbow, t / 0.45) else elbow:Lerp(tip, (t - 0.45) / 0.55)
			local featherLength = height * (0.5 + t * 0.7)
			local bottom = anchor + Vector3.new(side * 0.35 * t, -featherLength, 0.1 + t * 0.15)
			local down = (bottom - anchor).Unit
			local across = Vector3.new(side, 0, 0)
			local normal = across:Cross(down).Unit
			across = down:Cross(normal).Unit
			local cf = CFrame.fromMatrix((anchor + bottom) / 2, across, down, normal)
			self:Part(wing, Vector3.new(span / count * 1.6, featherLength, 0.05), cf, skinStyle, nil, "Feather")
		end
	else
		-- Membrane panels between finger bones.
		local fingers = 3
		for i = 1, fingers do
			local t = i / (fingers + 1)
			local fingerTip = elbow:Lerp(tip, t) + Vector3.new(side * 0.1, -height * (0.75 - t * 0.2), 0.3)
			self:Rod(wing, elbow, fingerTip, 0.07, boneStyle)
		end
		-- Membrane panels hanging from each bone, sloped to follow it.
		for _, bone in { { root, elbow }, { elbow, tip } } do
			local a, b = bone[1], bone[2]
			local drop = height * (0.62 + (if kind == "Torn" then self:Rand(-0.18, 0.05) else 0))
			local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
			local rotation = ModelKit.Along(flatA, flatB).Rotation * CFrame.Angles(0, math.pi / 2, 0)
			local slope = math.atan2(b.Y - a.Y, (flatB - flatA).Magnitude)
			local cf = CFrame.new((a + b) / 2) * rotation * CFrame.Angles(0, 0, slope) * CFrame.new(0, -drop / 2, 0.02)
			self:Part(wing, Vector3.new((b - a).Magnitude, drop, 0.05), cf, skinStyle, nil, "Membrane")
		end
	end
	return wing
end

-- An invisible ring around `center` that the animator spins (joint "Orbit");
-- `count` glowing orbs with light trails ride on it.
function ModelKit.Orbit(self: Kit, parent: BasePart | string, center: Vector3, radius: number, count: number, size: number, style: Style, trailColor: Color3?, tiltEach: number?): BasePart
	local ring = self:Segment("OrbitRing", parent, "Orbit", center, Vector3.new(0.2, 0.2, 0.2), CFrame.new(center), "Hidden")
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		local y = if tiltEach then math.sin(angle * 2) * tiltEach else 0
		local orb = self:Ball(ring, size, center + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius), style)
		orb.Name = "OrbitOrb"
		if trailColor then
			self:Trail(orb, Vector3.new(0, size * 0.4, 0), Vector3.new(0, -size * 0.4, 0), trailColor, 0.6)
		end
	end
	return ring
end

-- Final setup: Humanoid, animation attributes and streaming mode.
function ModelKit.Finish(self: Kit): Model
	local model = self.Model
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = self.HipHeight * self.Scale
	humanoid.Parent = model

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("ProceduralRig", true)
	model:SetAttribute("AnimStyle", self.Def.AnimStyle)
	model:SetAttribute("BossScale", self.Scale)
	model:SetAttribute("LegLength", self.LegLength)
	return model
end

return ModelKit
