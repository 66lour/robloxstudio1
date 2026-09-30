--!strict
-- Weapons and carried props shared by the boss designs. Positions are in rig
-- units; `grip` is where the hand holds it and `direction` is where the business
-- end points at rest (arms hang down, so "forward" is -Z).

local ModelKit = require(script.Parent.ModelKit)

type Kit = ModelKit.Kit
type Style = ModelKit.Style

local Armory = {}

local function perpendicular(direction: Vector3): Vector3
	local side = direction:Cross(Vector3.new(0, 1, 0))
	if side.Magnitude < 1e-3 then
		side = direction:Cross(Vector3.new(1, 0, 0))
	end
	return side.Unit
end

export type SwordOptions = {
	Length: number,
	Width: number,
	Blade: Style | string,
	Hilt: Style | string,
	Glow: Color3?,
	Runes: boolean?,
	Guard: number?,
	Serrated: boolean?,
	Broken: boolean?,
}

-- Straight blade with crossguard, grip and pommel. Returns the blade tip.
function Armory.Sword(kit: Kit, parent: BasePart | string, grip: Vector3, direction: Vector3, o: SwordOptions): Vector3
	local dir = direction.Unit
	local side = perpendicular(dir)
	local gripLength = 0.45 + o.Length * 0.12
	local guardPoint = grip + dir * gripLength * 0.5
	local pommel = grip - dir * gripLength * 0.5

	kit:Rod(parent, pommel, guardPoint, 0.12, o.Hilt)
	kit:Ball(parent, 0.2, pommel, o.Hilt)
	local guard = (o.Guard or 0.9) * math.max(1, o.Width * 3)
	kit:Rod(parent, guardPoint - side * guard / 2, guardPoint + side * guard / 2, Vector2.new(0.14, 0.12), o.Hilt)
	for _, sign in { -1, 1 } do
		kit:Spike(parent, guardPoint + side * guard / 2 * sign, guardPoint + side * (guard / 2 + 0.2) * sign + dir * 0.2, 0.12, o.Hilt)
	end

	local length = if o.Broken then o.Length * 0.6 else o.Length
	local tip = guardPoint + dir * length
	local bladeCF = ModelKit.Along(guardPoint, tip)
	-- Blade: a flat bar narrowing into a point, with a raised spine.
	local bodyEnd = guardPoint:Lerp(tip, 0.8)
	local bodyLength = (bodyEnd - guardPoint).Magnitude
	local blade = kit:Part(parent, Vector3.new(o.Width, 0.06, bodyLength), ModelKit.Along(guardPoint, bodyEnd), o.Blade, nil, "Blade")
	kit:Part(parent, Vector3.new(o.Width * 0.55, 0.06, (tip - bodyEnd).Magnitude), ModelKit.Along(bodyEnd, tip), o.Blade, nil, "BladeTip")
	if not o.Glow then
		kit:Part(parent, Vector3.new(0.05, 0.09, length * 0.85), bladeCF, o.Hilt, nil, "Fuller")
	end
	if o.Serrated then
		for i = 1, 4 do
			local at = guardPoint:Lerp(bodyEnd, i / 5)
			kit:Spike(parent, at + side * o.Width * 0.45, at + side * o.Width * 0.8 - dir * 0.1, 0.07, o.Blade, 1)
		end
	end
	if o.Glow then
		kit:Part(parent, Vector3.new(o.Width * 0.12, 0.08, length * 0.8), bladeCF, ModelKit.Neon(o.Glow), nil, "BladeGlow")
		if o.Runes then
			kit:Runes(parent, bladeCF * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, 0, -0.05), o.Width * 0.6, length * 0.5, 1, o.Glow)
		end
		-- The blade's +Z end is at the guard, -Z towards the tip.
		kit:Trail(blade, Vector3.new(0, 0, bodyLength / 2), Vector3.new(0, 0, -bodyLength / 2), o.Glow, 0.3)
	end
	return tip
end

export type ScytheOptions = {
	Length: number,
	Blade: number,
	Haft: Style | string,
	Edge: Style | string,
	Glow: Color3?,
}

-- Long haft held vertically, with a curved blade at the top. Returns the blade tip.
function Armory.Scythe(kit: Kit, parent: BasePart | string, grip: Vector3, o: ScytheOptions): Vector3
	local bottom = grip - Vector3.new(0, o.Length * 0.35, 0)
	local top = grip + Vector3.new(0, o.Length * 0.65, 0)
	kit:Rod(parent, bottom, top, 0.16, o.Haft, true)
	kit:Spike(parent, bottom, bottom - Vector3.new(0, 0.5, 0), 0.14, o.Edge)
	-- Wrapped grips.
	for _, y in { 0, 0.5 } do
		kit:Rod(parent, grip + Vector3.new(0, y - 0.15, 0), grip + Vector3.new(0, y + 0.15, 0), 0.2, "Leather", true)
	end
	-- Curved blade sweeping forward and down from the top.
	local point = top
	local heading = Vector3.new(0, 0.2, -1).Unit
	local segments = 6
	local tip = top
	for i = 1, segments do
		local step = o.Blade / segments
		local nextPoint = point + heading * step
		local width = 0.55 * (1 - (i - 1) / segments * 0.85)
		kit:Part(parent, Vector3.new(0.06, width, step * 1.1), ModelKit.Along(point, nextPoint) * CFrame.new(0, -width / 2 + 0.05, 0), o.Edge, nil, "ScytheBlade")
		if o.Glow then
			kit:Part(parent, Vector3.new(0.08, 0.06, step * 1.1), ModelKit.Along(point, nextPoint) * CFrame.new(0, -width + 0.06, 0), ModelKit.Neon(o.Glow), nil, "ScytheEdge")
		end
		point = nextPoint
		tip = nextPoint
		heading = ModelKit.Rotate(heading, Vector3.new(1, 0, 0), -0.28)
	end
	return tip
end

export type StaffOptions = {
	Length: number,
	Haft: Style | string,
	Orb: Style?,
	OrbSize: number?,
	Glow: Color3?,
	Prongs: number?,
	Skull: boolean?,
}

-- Walking staff held vertically, topped with a caged orb. Returns the orb centre.
function Armory.Staff(kit: Kit, parent: BasePart | string, grip: Vector3, o: StaffOptions): (Vector3, BasePart?)
	local bottom = grip - Vector3.new(0, o.Length * 0.45, 0)
	local top = grip + Vector3.new(0, o.Length * 0.55, 0)
	-- Slightly crooked haft in three pieces.
	local a = bottom:Lerp(top, 0.35) + Vector3.new(0.06, 0, 0)
	local b = bottom:Lerp(top, 0.7) - Vector3.new(0.05, 0, 0.04)
	kit:Rod(parent, bottom, a, 0.14, o.Haft)
	kit:Rod(parent, a, b, 0.13, o.Haft)
	kit:Rod(parent, b, top, 0.12, o.Haft)
	local orbSize = o.OrbSize or 0.45
	local center = top + Vector3.new(0, orbSize * 0.8, 0)
	local orb: BasePart? = nil
	if o.Skull then
		kit:Ellipsoid(parent, Vector3.new(0.45, 0.42, 0.5), center, "Bone")
		for _, side in { -1, 1 } do
			kit:Part(parent, Vector3.new(0.1, 0.07, 0.04), CFrame.new(center + Vector3.new(side * 0.1, 0.02, -0.25)), ModelKit.Neon(o.Glow or Color3.new(1, 1, 1)), nil, "Eye")
		end
	end
	if o.Orb then
		orb = kit:Ball(parent, orbSize, if o.Skull then center + Vector3.new(0, orbSize * 0.9, 0) else center, o.Orb)
	end
	local prongs = o.Prongs or 4
	for i = 0, prongs - 1 do
		local angle = i / prongs * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- Up and out, curling back in over the orb.
		kit:Horn(parent, top, out + Vector3.new(0, 1.3, 0), orbSize * 1.6, 0.07, 1.3, out:Cross(Vector3.new(0, 1, 0)), o.Haft, 3)
	end
	if o.Glow and orb then
		kit:Light(orb, o.Glow, 8, 2)
		kit:Emit(orb, "Wisps", o.Glow, { Rate = 10 })
	end
	return center, orb
end

export type HammerOptions = {
	Length: number,
	Head: Vector3, -- X across the haft (striking faces), Y height, Z along the haft
	Haft: Style | string,
	HeadStyle: Style | string,
	Glow: Color3?,
}

-- Two-handed maul, head forward at rest. Returns the head centre.
function Armory.Hammer(kit: Kit, parent: BasePart | string, grip: Vector3, direction: Vector3, o: HammerOptions): Vector3
	local dir = direction.Unit
	local butt = grip - dir * o.Length * 0.25
	local neck = grip + dir * o.Length * 0.75
	kit:Rod(parent, butt, neck, 0.2, o.Haft, true)
	kit:Ball(parent, 0.3, butt, o.HeadStyle)
	local headCF = ModelKit.Along(grip, neck).Rotation + (neck + dir * o.Head.Z * 0.3)
	local head = kit:Part(parent, o.Head, headCF, o.HeadStyle, nil, "HammerHead")
	for _, sign in { -1, 1 } do
		kit:Part(parent, Vector3.new(o.Head.X * 1.12, o.Head.Y * 0.2, o.Head.Z * 1.05), headCF * CFrame.new(0, sign * o.Head.Y * 0.38, 0), "DarkMetal", nil, "HammerBand")
	end
	-- Top spike past the end of the haft.
	kit:Spike(parent, headCF.Position, (headCF * CFrame.new(0, 0, -o.Head.Z * 1.4)).Position, math.min(o.Head.Y, o.Head.Z) * 0.45, o.HeadStyle)
	if o.Glow then
		-- Runes on the upper and lower faces of the head.
		kit:Runes(parent, headCF * CFrame.new(0, o.Head.Y / 2 + 0.01, 0) * CFrame.Angles(math.pi / 2, 0, 0), o.Head.X * 0.8, o.Head.Z * 0.3, 3, o.Glow)
		kit:Runes(parent, headCF * CFrame.new(0, -o.Head.Y / 2 - 0.01, 0) * CFrame.Angles(-math.pi / 2, 0, 0), o.Head.X * 0.8, o.Head.Z * 0.3, 3, o.Glow)
		kit:Emit(head, "Embers", o.Glow, { Rate = 8 })
	end
	return headCF.Position
end

-- Ship's anchor hanging from the hand on a chain. Returns the anchor crown.
function Armory.Anchor(kit: Kit, parent: BasePart | string, grip: Vector3, length: number, style: Style | string, chain: Style | string, glow: Color3?): Vector3
	local ring = grip - Vector3.new(0, 0.3, 0)
	local shankTop = ring - Vector3.new(0, 0.25, 0)
	local crown = shankTop - Vector3.new(0, length, 0)
	kit:Ring(parent, CFrame.new(ring) * CFrame.Angles(math.pi / 2, 0, 0), 0.25, 8, Vector3.new(0.12, 0.12, 0.22), chain)
	kit:Rod(parent, shankTop, crown, 0.26, style)
	kit:Rod(parent, shankTop - Vector3.new(0.7, 0.3, 0), shankTop - Vector3.new(-0.7, 0.3, 0), 0.2, style)
	for _, side in { -1, 1 } do
		local armEnd = crown + Vector3.new(side * length * 0.45, length * 0.3, 0)
		kit:Rod(parent, crown, crown + Vector3.new(side * length * 0.3, -0.05, 0), 0.24, style)
		kit:Rod(parent, crown + Vector3.new(side * length * 0.3, -0.05, 0), armEnd, 0.22, style)
		kit:Spike(parent, armEnd, armEnd + Vector3.new(side * 0.25, 0.45, 0), 0.3, style)
	end
	if glow then
		kit:Runes(parent, CFrame.new(shankTop:Lerp(crown, 0.5)) * CFrame.new(0, 0, -0.14), 0.24, length * 0.25, 1, glow)
	end
	return crown
end

-- Round shield on the outside of a forearm. `outward` points away from the body.
function Armory.Shield(kit: Kit, parent: BasePart | string, center: Vector3, outward: Vector3, diameter: number, face: Style | string, rim: Style | string, emblem: Color3?)
	local out = outward.Unit
	local cf = ModelKit.LookAt(center, center + out) * CFrame.Angles(0, math.pi / 2, 0)
	kit:Part(parent, Vector3.new(0.14, diameter, diameter), cf, face, Enum.PartType.Cylinder, "Shield")
	kit:Part(parent, Vector3.new(0.1, diameter + 0.12, diameter + 0.12), cf * CFrame.new(-0.03, 0, 0), rim, Enum.PartType.Cylinder, "ShieldRim")
	kit:Ball(parent, diameter * 0.22, center + out * 0.1, rim)
	if emblem then
		kit:Runes(parent, ModelKit.LookAt(center + out * 0.09, center + out * 2), diameter * 0.5, diameter * 0.35, 1, emblem)
	end
end

-- Lantern hanging below `hook`. Returns the lantern part (for lights).
function Armory.Lantern(kit: Kit, parent: BasePart | string, hook: Vector3, size: number, frame: Style | string, flame: Color3): BasePart
	local center = hook - Vector3.new(0, size * 1.2, 0)
	kit:Chain(parent, hook, center + Vector3.new(0, size * 0.6, 0), 0.18, frame)
	local glass = kit:Part(parent, Vector3.new(size * 0.7, size, size * 0.7), CFrame.new(center), ModelKit.Neon(flame, 0.35), nil, "LanternGlow")
	kit:Part(parent, Vector3.new(size * 0.9, size * 0.14, size * 0.9), CFrame.new(center + Vector3.new(0, size * 0.55, 0)), frame, nil, "LanternCap")
	kit:Part(parent, Vector3.new(size * 0.9, size * 0.12, size * 0.9), CFrame.new(center - Vector3.new(0, size * 0.55, 0)), frame, nil, "LanternBase")
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			kit:Part(parent, Vector3.new(0.05, size, 0.05), CFrame.new(center + Vector3.new(x * size * 0.37, 0, z * size * 0.37)), frame, nil, "LanternBar")
		end
	end
	kit:Spike(parent, center + Vector3.new(0, size * 0.6, 0), center + Vector3.new(0, size * 0.95, 0), size * 0.3, frame, 1)
	kit:Light(glass, flame, 7, 2)
	kit:Emit(glass, "Embers", flame, { Rate = 5, Size = 0.15 })
	return glass
end

-- Curved claws off the end of a hand, pointing down and forward.
function Armory.Claws(kit: Kit, parent: BasePart | string, hand: Vector3, count: number, length: number, spread: number, style: Style | string)
	for i = 1, count do
		local t = if count == 1 then 0 else (i - 1) / (count - 1) - 0.5
		local base = hand + Vector3.new(t * spread, 0.05, -0.12)
		kit:Horn(parent, base, Vector3.new(t * 0.3, -1, -0.35), length, 0.1, 1.1, Vector3.new(1, 0, 0), style, 3)
	end
end

return Armory
