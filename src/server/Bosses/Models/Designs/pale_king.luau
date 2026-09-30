--!strict
-- The Pale King: sovereign of the dreaming dead. A towering undead monarch in
-- ornate white-marble armor chased with gold and crimson runes, a skull face
-- under a tall crown of spires and blood-red gems, a floating halo of blades,
-- an ermine-trimmed crimson cape of state, and a great bone-white sword held
-- point-down before him like a scepter.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local blood: Color3 = def.Appearance.Aura
	local marble = "Marble"
	local granite = ModelKit.Tint("PolishedGranite", { Color = rgb(206, 202, 196) })
	local gold = "Gold"
	local crimson = ModelKit.Tint("Cloth", { Color = rgb(120, 14, 26) })
	local ermine = ModelKit.Tint("Fur", { Color = rgb(236, 232, 224) })
	local bone = "Bone"
	local gem = ModelKit.Neon(blood)

	local rig = kit:Rig({
		Legs = { Thigh = 1.25, Shin = 1.3, Spacing = 0.5, Width = 0.5, Style = marble, ShinStyle = granite },
		Hips = { Size = V(1.6, 0.6, 1.0), Style = marble },
		Chest = { Size = V(2.1, 2.0, 1.2), Style = marble, Lean = 0 },
		Arms = { Upper = 1.3, Fore = 1.35, Width = 0.5, ShoulderX = 1.35, Style = marble, ForeStyle = granite },
		Head = { Size = V(0.9, 1.0, 1.0), Style = "Hidden", Neck = 0.3 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Ornate breastplate, gorget and a skull-buckled belt.
	kit:Plate("Chest", V(2.0, 1.6, 0.14), C * CFrame.new(0, 0.1, -0.65), marble, gold, blood, 3)
	kit:Part("Chest", V(0.16, 1.7, 0.18), C * CFrame.new(0, 0.1, -0.74), gold)
	kit:Ball("Chest", 0.34, C * CFrame.new(0, 0.45, -0.8), gem)
	kit:Light(rig.Chest, blood, 10, 1.5)
	kit:Ring("Chest", CFrame.new(P.Neck + V(0, 0.05, 0)), 0.5, 12, V(0.3, 0.26, 0.2), marble)
	kit:Part("Hips", V(1.75, 0.24, 1.1), CFrame.new(P.Waist - V(0, 0.05, 0)), gold)
	kit:Ellipsoid("Hips", V(0.4, 0.4, 0.2), CFrame.new(P.Waist + V(0, -0.05, -0.6)), bone)
	kit:Robe("Hips", P.Waist - V(0, 0.1, 0), 0.8, 1.0, 1.1, 8, marble, 0.8, false)
	kit:Part("Hips", V(0.6, 1.6, 0.06), CFrame.new(P.Waist + V(0, -0.85, -0.62)), crimson)
	kit:Runes("Hips", CFrame.new(P.Waist + V(0, -0.7, -0.66)), 0.4, 0.3, 1, rgb(230, 190, 110))

	-- Layered, spiked pauldrons with gold trim.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder = P[prefix .. "Shoulder"]
		for layer = 0, 2 do
			local cf = CFrame.new(shoulder + V(side * (0.1 + layer * 0.12), 0.35 - layer * 0.22, 0)) * CFrame.Angles(0, 0, side * (-0.35 - layer * 0.2))
			kit:Plate(prefix .. "UpperArm", V(1.15 - layer * 0.12, 0.2, 1.1 - layer * 0.08), cf, marble, gold)
		end
		kit:SpikeRow(prefix .. "UpperArm", shoulder + V(side * 0.15, 0.5, -0.4), shoulder + V(side * 0.15, 0.5, 0.4), 3, 0.8, V(side * 0.3, 1, 0), 0.16, gold)
		kit:Part(prefix .. "Forearm", V(0.6, 0.35, 0.6), CFrame.new(P[prefix .. "Elbow"] - V(0, 0.2, 0)), gold)
		kit:Part(prefix .. "Forearm", V(0.5, 0.4, 0.45), CFrame.new(P[prefix .. "Hand"] - V(0, 0.1, 0)), marble)
	end

	-- Skull face, crown of spires and gems, halo of floating blades.
	local H = F.Head
	kit:Ellipsoid("Head", V(0.9, 0.9, 1.0), H * CFrame.new(0, 0.1, 0.05), bone)
	kit:Part("Head", V(0.66, 0.32, 0.5), H * CFrame.new(0, -0.24, -0.22), bone)
	for _, side in { -1, 1 } do
		kit:Ball("Head", 0.28, H * CFrame.new(side * 0.2, -0.02, -0.4), { Material = Enum.Material.SmoothPlastic, Color = rgb(10, 6, 8) })
	end
	kit:Eyes("Head", H * CFrame.new(0, -0.02, -0.52), 0.4, V(0.12, 0.08, 0.05), def.Appearance.Eyes)
	for i = -2, 2 do
		kit:Part("Head", V(0.07, 0.1, 0.06), H * CFrame.new(i * 0.1, -0.42, -0.42), bone)
	end
	kit:Segment("Jaw", "Head", "Jaw", (H * CFrame.new(0, -0.35, 0.05)).Position, V(0.6, 0.14, 0.48), H * CFrame.new(0, -0.52, -0.2), bone)
	local crown = H * CFrame.new(0, 0.45, 0.05)
	kit:Ring("Head", crown, 0.44, 14, V(0.22, 0.22, 0.1), gold)
	kit:Crown("Head", crown * CFrame.new(0, 0.1, 0), 0.44, 9, 0.95, 0.12, gold, 0.08)
	for i = 0, 8 do
		local angle = i / 9 * math.pi * 2
		kit:Ball("Head", 0.12, crown * CFrame.new(math.cos(angle) * 0.46, 0.02, math.sin(angle) * 0.46), gem)
	end
	local halo = kit:Orbit("Head", (H * CFrame.new(0, 0.6, 0.1)).Position, 1.4, 0, 0.1, gem)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		local center = (H * CFrame.new(0, 0.6, 0.1)).Position
		local out = V(math.cos(angle), 0, math.sin(angle))
		kit:Spike(halo, center + out * 1.15, center + out * 1.85, 0.12, granite, 2)
		kit:Part(halo, V(0.35, 0.05, 0.12), ModelKit.LookAt(center + out * 1.1, center + out * 2), gold)
	end

	-- Ermine mantle and a long crimson cape of state.
	kit:Ellipsoid("Chest", V(2.5, 0.6, 1.6), C * CFrame.new(0, 0.9, 0.05), ermine)
	for i = 0, 6 do
		kit:Ball("Chest", 0.1, C * CFrame.new(-1.0 + i * 0.33, 0.85, -0.72), { Material = Enum.Material.SmoothPlastic, Color = rgb(20, 20, 20) })
	end
	kit:Cape("Chest", P.Back + V(0, 0.6, 0.2), 2.4, 4.6, 4, crimson, ermine)

	-- The great sword, point-down before him.
	Armory.Sword(kit, "RightForearm", P.RightHand, V(0, -1, -0.25), {
		Length = 3.4,
		Width = 0.46,
		Blade = granite,
		Hilt = gold,
		Glow = blood,
		Runes = true,
		Guard = 1.2,
	})

	-- Armored boots.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Part(prefix .. "Shin", V(0.62, 0.35, 0.95), CFrame.new(P[prefix .. "Foot"] + V(0, 0.17, -0.15)), marble)
		kit:Ellipsoid(prefix .. "Thigh", V(0.62, 0.45, 0.6), CFrame.new(P[prefix .. "Knee"] + V(0, 0.05, -0.08)), gold)
	end

	kit:Emit(rig.Hips, "Mist", blood:Lerp(Color3.new(0, 0, 0), 0.5), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 5 })
	kit:Emit(rig.Chest, "Wisps", blood, { Rate = 5 })
end
