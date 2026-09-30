--!strict
-- Nyx'thal, Maw of the Starless Void: a floating cosmic horror. A bulbous body
-- of glossy void speckled with stars, a colossal maw ringed with teeth and lit
-- from deep inside, six burning eyes, a crown of curling horns, torn membrane
-- wings, long clawed arms, drifting tentacles, and whole stars caught in orbit
-- around it.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local void: Color3 = def.Appearance.Aura
	local eyeColor: Color3 = def.Appearance.Eyes
	local skin = { Material = Enum.Material.Glass, Color = rgb(20, 14, 32), Reflectance = 0.05 }
	local hide = { Material = Enum.Material.Basalt, Color = rgb(30, 22, 44) }
	local tooth = { Material = Enum.Material.Limestone, Color = rgb(226, 220, 236) }
	local membrane = ModelKit.Ghost(rgb(120, 40, 190), 0.35)
	local star = ModelKit.Neon(rgb(240, 236, 255))

	local rig = kit:Rig({
		Hover = 3.2,
		Hips = { Size = V(1.8, 0.8, 1.4), Style = skin, Round = true },
		Chest = { Size = V(2.8, 2.6, 2.2), Style = skin, Lean = 0.1, Round = true, Fat = 1.2 },
		Arms = { Upper = 1.6, Fore = 1.8, Width = 0.55, ShoulderX = 1.7, Drop = 0.5, Style = hide, Round = true },
		Head = { Size = V(1.8, 1.6, 1.8), Style = "Hidden", Neck = 0.1 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Stars scattered across the void-flesh, ridged plates on the back.
	for i = 1, 24 do
		local theta = kit:Rand(0, math.pi * 2)
		local phi = kit:Rand(-1.1, 1.1)
		local offset = V(math.cos(theta) * math.cos(phi) * 1.62, math.sin(phi) * 1.5, math.sin(theta) * math.cos(phi) * 1.3)
		kit:Ball("Chest", kit:Rand(0.06, 0.14), C * CFrame.new(offset), star)
	end
	kit:SpikeRow("Chest", (C * CFrame.new(0, 1.3, 1.0)).Position, (C * CFrame.new(0, -1.2, 1.2)).Position, 7, 1.2, (C.Rotation * CFrame.new(0, 0.4, 1)).Position, 0.4, hide)

	-- The maw: domed skull, ring of teeth, a glowing gullet and a hinged jaw.
	local H = F.Head
	kit:Ellipsoid("Head", V(2.0, 1.3, 2.0), H * CFrame.new(0, 0.3, 0.05), skin)
	local gullet = kit:Ball("Head", 0.9, H * CFrame.new(0, -0.2, -0.3), ModelKit.Neon(void))
	gullet.Name = "Gullet"
	kit:Emit(gullet, "Void", void, { Rate = 10, Size = 0.9 })
	kit:Light(gullet, void, 16, 3)
	for i = 0, 10 do
		local angle = math.pi * (0.1 + 0.8 * i / 10)
		local base = (H * CFrame.new(math.cos(angle) * 0.92, -0.12, -math.sin(angle) * 0.9)).Position
		kit:Spike("Head", base, base + V(0, -0.5 - (i % 2) * 0.2, 0), 0.18, tooth, 2)
	end
	local jawPivot = (H * CFrame.new(0, -0.3, 0.6)).Position
	local jaw = kit:Segment("Jaw", "Head", "Jaw", jawPivot, V(1.8, 0.45, 1.8), H * CFrame.new(0, -0.65, -0.1), hide)
	kit:Ellipsoid(jaw, V(1.9, 0.6, 1.9), H * CFrame.new(0, -0.72, -0.1), skin)
	for i = 0, 10 do
		local angle = math.pi * (0.1 + 0.8 * i / 10)
		local base = (H * CFrame.new(math.cos(angle) * 0.85, -0.45, -math.sin(angle) * 0.83 - 0.05)).Position
		kit:Spike(jaw, base, base + V(0, 0.5 + (i % 2) * 0.2, 0), 0.17, tooth, 2)
	end

	-- Six burning eyes of different sizes.
	local eyes: { { Position: Vector3, Size: number } } = {
		{ Position = V(-0.45, 0.45, -0.85), Size = 0.34 },
		{ Position = V(0.45, 0.45, -0.85), Size = 0.34 },
		{ Position = V(-0.85, 0.7, -0.45), Size = 0.22 },
		{ Position = V(0.85, 0.7, -0.45), Size = 0.22 },
		{ Position = V(-0.2, 0.9, -0.7), Size = 0.16 },
		{ Position = V(0.25, 0.92, -0.68), Size = 0.14 },
	}
	for _, eye in eyes do
		local part = kit:Ball("Head", eye.Size, H * CFrame.new(eye.Position), ModelKit.Neon(eyeColor))
		part.Name = "Eye"
		kit:Emit(part, "Wisps", eyeColor, { Rate = 3, Size = eye.Size * 0.6 })
	end

	-- Crown of curling horns.
	for i = 0, 5 do
		local angle = math.pi * (0.15 + 0.7 * i / 5)
		local base = (H * CFrame.new(math.cos(angle) * 0.8, 0.75, math.sin(angle) * 0.6 + 0.2)).Position
		local out = V(math.cos(angle), 0, math.sin(angle) * 0.6 + 0.3)
		kit:Horn("Head", base, out + V(0, 1.2, 0), 1.6 + (i % 2) * 0.5, 0.3, -1.8, out:Cross(V(0, 1, 0)), hide, 5)
	end

	-- Torn membrane wings and long clawed arms.
	for _, side in { -1, 1 } do
		kit:Wing("Chest", side, (C * CFrame.new(side * 0.8, 0.9, 0.9)).Position, 4.2, 3.0, "Torn", hide, membrane)
		local prefix = if side < 0 then "Left" else "Right"
		kit:SpikeRow(prefix .. "Forearm", P[prefix .. "Elbow"] + V(side * 0.35, 0, 0.2), P[prefix .. "Hand"] + V(side * 0.3, 0.3, 0.2), 4, 0.6, V(side, 0.4, 0.5), 0.2, hide)
		Armory.Claws(kit, prefix .. "Forearm", P[prefix .. "Hand"], 3, 1.2, 0.5, tooth)
		kit:Ball(prefix .. "Forearm", 0.18, CFrame.new(P[prefix .. "Elbow"] + V(0, -0.5, -0.3)), ModelKit.Neon(eyeColor))
	end

	-- Tentacles drifting beneath, dotted with glowing suckers.
	for index = 1, 4 do
		local angle = (index - 0.5) / 4 * math.pi * 2
		local base = P.Pelvis + V(math.cos(angle) * 0.7, -0.35, math.sin(angle) * 0.55)
		local direction = V(math.cos(angle) * 0.35, -1, math.sin(angle) * 0.35)
		kit:Tail("Hips", `Tentacle{string.char(64 + index)}`, base, direction, 4.2, 0.42, 6, skin, 1.4, V(-math.sin(angle), 0, math.cos(angle)), function(segment, a, b, i)
			if i % 2 == 0 then
				kit:Ball(segment, 0.12, a:Lerp(b, 0.5) + V(0, 0, -0.18), ModelKit.Neon(void))
			end
		end)
	end

	-- Captured stars in orbit, void smoke and starlight.
	kit:Orbit("Chest", C.Position, 4.2, 5, 0.5, star, void, 0.9)
	kit:Emit(rig.Chest, "Void", rgb(40, 10, 70), { Rate = 10, Size = 1.4 })
	kit:Emit(rig.Chest, "Spectral", rgb(220, 200, 255), { Rate = 8 })
end
