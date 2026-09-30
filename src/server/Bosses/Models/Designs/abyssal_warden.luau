--!strict
-- Abyssal Warden: the jailer of a drowned prison, in barnacled deep-sea armor.
-- An angler-fish helm with a glowing lure and a toothed visor, face tentacles
-- trailing beneath it, coral-spiked pauldrons, a glowing porthole on the chest,
-- a ring of prison keys and a lantern at its belt, kelp, and a giant anchor on
-- a chain. Bubbles rise off it wherever it walks.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local abyss: Color3 = def.Appearance.Aura
	local armor = { Material = Enum.Material.CorrodedMetal, Color = rgb(44, 70, 76) }
	local darkArmor = { Material = Enum.Material.CorrodedMetal, Color = rgb(28, 42, 48) }
	local barnacle = { Material = Enum.Material.Limestone, Color = rgb(196, 190, 170) }
	local coral = { Material = Enum.Material.Limestone, Color = rgb(222, 214, 196) }
	local flesh = { Material = Enum.Material.Mud, Color = rgb(58, 84, 90) }
	local kelp = ModelKit.Tint("Moss", { Color = rgb(34, 64, 42) })

	local rig = kit:Rig({
		Legs = { Thigh = 1.1, Shin = 1.2, Spacing = 0.65, Width = 0.7, Style = armor, ShinStyle = darkArmor },
		Hips = { Size = V(1.8, 0.8, 1.2), Style = darkArmor },
		Chest = { Size = V(2.6, 2.2, 1.6), Style = armor, Lean = 0.2 },
		Arms = { Upper = 1.35, Fore = 1.5, Width = 0.7, ShoulderX = 1.75, Drop = 0.4, Style = armor, ForeStyle = darkArmor },
		Head = { Size = V(1.1, 1.1, 1.1), Style = armor, Neck = 0.1 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Chest: runed plate with a glowing porthole, barnacle crust.
	kit:Plate("Chest", V(2.3, 1.8, 0.14), C * CFrame.new(0, 0.05, -0.82), armor, darkArmor, abyss, 4)
	local porthole = C * CFrame.new(0, 0.3, -0.92)
	kit:Ring("Chest", porthole * CFrame.Angles(math.pi / 2, 0, 0), 0.45, 12, V(0.18, 0.2, 0.18), "Rust")
	local glass = kit:Part("Chest", V(0.08, 0.8, 0.8), porthole * CFrame.Angles(0, math.pi / 2, 0), ModelKit.Ghost(abyss, 0.1), Enum.PartType.Cylinder)
	glass.Name = "Porthole"
	kit:Emit(glass, "Bubbles", abyss, { Rate = 8 })
	kit:Light(glass, abyss, 12, 2)
	for i = 1, 14 do
		local offset = V(kit:Rand(-1.2, 1.2), kit:Rand(-1.0, 1.0), kit:Rand(-0.85, 0.85))
		kit:Ball("Chest", kit:Rand(0.12, 0.26), C * CFrame.new(offset.X, offset.Y, if math.abs(offset.Z) > 0.5 then offset.Z else 0.82), barnacle)
	end

	-- Angler helm: toothed visor, lure, trailing face tentacles.
	local H = F.Head
	kit:Ellipsoid("Head", V(1.3, 1.1, 1.35), H * CFrame.new(0, 0.1, 0.05), armor)
	kit:Part("Head", V(1.0, 0.35, 0.12), H * CFrame.new(0, -0.05, -0.62), ModelKit.Neon(def.Appearance.Eyes, 0.15))
	for i = -3, 3 do
		kit:Spike("Head", (H * CFrame.new(i * 0.13, 0.15, -0.64)).Position, (H * CFrame.new(i * 0.13, -0.08, -0.7)).Position, 0.08, coral, 1)
		kit:Spike("Head", (H * CFrame.new(i * 0.13, -0.25, -0.64)).Position, (H * CFrame.new(i * 0.13, -0.02, -0.7)).Position, 0.08, coral, 1)
	end
	kit:Horn("Head", (H * CFrame.new(0, 0.6, -0.1)).Position, V(0, 1, -0.9), 1.3, 0.12, 2.4, V(1, 0, 0), darkArmor, 6)
	local lure = kit:Ball("Head", 0.35, H * CFrame.new(0, 0.62, -1.15), ModelKit.Neon(abyss))
	lure.Name = "Lure"
	kit:Light(lure, abyss, 10, 3)
	kit:Emit(lure, "Wisps", abyss, { Rate = 8 })
	for index, x in { -0.35, -0.12, 0.12, 0.35 } do
		kit:Tail("Head", `Tentacle{string.char(64 + index)}`, (H * CFrame.new(x, -0.45, -0.35)).Position, V(x * 0.4, -1, -0.2), 1.6, 0.16, 4, flesh, 0.8, V(1, 0, 0))
	end

	-- Coral-spiked pauldrons, barnacled arms, anchor and chain.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder = P[prefix .. "Shoulder"]
		kit:Ellipsoid(prefix .. "UpperArm", V(1.4, 0.9, 1.4), CFrame.new(shoulder + V(side * 0.15, 0.3, 0)), darkArmor)
		kit:SpikeRow(prefix .. "UpperArm", shoulder + V(side * 0.1, 0.65, -0.45), shoulder + V(side * 0.1, 0.65, 0.45), 4, 1.0, V(side * 0.5, 1, 0), 0.22, coral)
		for i = 1, 4 do
			kit:Ball(prefix .. "UpperArm", kit:Rand(0.12, 0.2), shoulder + V(side * kit:Rand(0.3, 0.7), kit:Rand(-0.1, 0.4), kit:Rand(-0.5, 0.5)), barnacle)
		end
		local hand = P[prefix .. "Hand"]
		kit:Part(prefix .. "Forearm", V(0.85, 0.6, 0.85), CFrame.new(hand - V(0, 0.1, 0)), armor)
		Armory.Claws(kit, prefix .. "Forearm", hand - V(0, 0.35, 0), 3, 0.5, 0.45, darkArmor)
	end
	Armory.Anchor(kit, "RightForearm", P.RightHand - V(0, 0.2, 0), 3.2, "DarkMetal", "Rust", abyss)

	-- Belt: keys, lantern, kelp.
	kit:Part("Hips", V(1.95, 0.25, 1.3), CFrame.new(P.Waist - V(0, 0.1, 0)), "Leather")
	local keyRing = P.Waist + V(0.8, -0.45, -0.45)
	kit:Ring("Hips", CFrame.new(keyRing) * CFrame.Angles(math.pi / 2, 0, 0), 0.28, 10, V(0.08, 0.08, 0.14), "Rust")
	for i = 0, 3 do
		local angle = i / 4 * math.pi - math.pi * 0.9
		local base = keyRing + V(math.cos(angle) * 0.28, math.sin(angle) * 0.28, 0)
		kit:Rod("Hips", base, base + V(0.05, -0.55, 0), 0.06, "DarkGold")
		kit:Part("Hips", V(0.16, 0.1, 0.05), CFrame.new(base + V(0.08, -0.5, 0)), "DarkGold")
	end
	Armory.Lantern(kit, "Hips", P.Waist + V(-0.8, -0.2, -0.45), 0.5, "Rust", abyss)
	kit:Strips("Hips", P.Waist + V(-0.9, -0.2, 0.62), P.Waist + V(0.9, -0.2, 0.62), 7, 0.8, 1.8, 0.04, kelp)
	kit:Strips("Hips", P.Waist + V(-0.9, -0.2, -0.64), P.Waist + V(-0.2, -0.2, -0.64), 3, 0.6, 1.3, 0.04, kelp)

	-- Heavy boots, dripping water, rising bubbles.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Part(prefix .. "Shin", V(0.95, 0.45, 1.25), CFrame.new(P[prefix .. "Foot"] + V(0, 0.22, -0.15)), darkArmor)
		kit:Ellipsoid(prefix .. "Thigh", V(0.85, 0.55, 0.85), CFrame.new(P[prefix .. "Knee"] + V(0, 0.05, -0.1)), armor)
	end
	kit:Emit(rig.Chest, "Bubbles", abyss, { Rate = 6, Size = 0.3 })
	kit:Emit(rig.Hips, "Drips", rgb(120, 180, 190), { Rate = 5 })
	kit:Emit(rig.Hips, "Mist", abyss:Lerp(Color3.new(0, 0, 0), 0.5), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 4 })
end
