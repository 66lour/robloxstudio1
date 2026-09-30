--!strict
-- Gravebound Golem: a walking mausoleum of cobblestone and polished granite. Its
-- chest is a crypt doorway glowing with trapped souls, tombstones form its
-- shoulders, glowing runes and engraved names cover the stones, moss and vines
-- drape it, and a bell tower rises from its back. One cyclopean eye.

local Models = script.Parent.Parent
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local souls: Color3 = def.Appearance.Aura
	local stone = "Cobblestone"
	local granite = "PolishedGranite"
	local engraving = { Material = Enum.Material.Slate, Color = rgb(34, 34, 38) }
	local vine = ModelKit.Tint("Moss", { Color = rgb(58, 86, 44) })

	local rig = kit:Rig({
		Legs = { Thigh = 0.95, Shin = 1.0, Spacing = 0.75, Width = 0.85, Style = stone, ShinStyle = granite },
		Hips = { Size = V(2.1, 0.8, 1.3), Style = stone },
		Chest = { Size = V(3.0, 2.3, 1.7), Style = stone, Lean = 0.18 },
		Arms = { Upper = 1.3, Fore = 1.55, Width = 0.85, ShoulderX = 2.0, Drop = 0.45, Style = stone, ForeStyle = granite },
		Head = { Size = V(0.95, 0.85, 0.95), Style = granite, Neck = -0.05 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Crypt doorway: dark recess, glowing soul-portal, pillars, arch and pediment.
	kit:Part("Chest", V(1.15, 1.35, 0.1), C * CFrame.new(0, -0.1, -0.86), engraving)
	local portal = kit:Part("Chest", V(1.0, 1.2, 0.06), C * CFrame.new(0, -0.1, -0.9), ModelKit.Ghost(souls, 0.25))
	portal.Name = "SoulPortal"
	kit:Emit(portal, "Spectral", souls, { Rate = 10 })
	kit:Light(portal, souls, 12, 2.5)
	for _, side in { -1, 1 } do
		kit:Part("Chest", V(0.24, 1.5, 0.24), C * CFrame.new(side * 0.72, -0.12, -0.92), granite)
		kit:Part("Chest", V(0.36, 0.16, 0.36), C * CFrame.new(side * 0.72, 0.68, -0.92), granite)
		kit:Part("Chest", V(0.36, 0.16, 0.36), C * CFrame.new(side * 0.72, -0.9, -0.92), granite)
	end
	for i = 0, 4 do
		local angle = math.pi * (i / 4)
		kit:Part("Chest", V(0.3, 0.2, 0.22), C * CFrame.new(math.cos(angle) * 0.55, 0.6 + math.sin(angle) * 0.35, -0.92) * CFrame.Angles(0, 0, angle - math.pi / 2), granite)
	end
	for _, side in { -1, 1 } do
		kit:Rod("Chest", (C * CFrame.new(side * 0.95, 1.0, -0.9)).Position, (C * CFrame.new(0, 1.35, -0.9)).Position, Vector2.new(0.18, 0.14), granite)
	end
	kit:Ellipsoid("Chest", V(0.3, 0.3, 0.2), C * CFrame.new(0, 1.12, -0.95), "Bone")

	-- Engraved names, soul-cracks and runes over the stones.
	for _, side in { -1, 1 } do
		for row = 0, 3 do
			kit:Part("Chest", V(0.05, 0.05, 0.9 - row * 0.12), C * CFrame.new(side * 1.52, 0.7 - row * 0.3, -0.05), engraving)
		end
		kit:Runes("Chest", C * CFrame.new(side * 1.12, -0.75, -0.86), 0.55, 0.25, 2, souls)
	end
	kit:Rod("Chest", (C * CFrame.new(-1.3, 0.9, -0.87)).Position, (C * CFrame.new(-0.95, 0.3, -0.87)).Position, 0.05, ModelKit.Neon(souls))
	kit:Rod("Chest", (C * CFrame.new(1.1, -0.3, -0.87)).Position, (C * CFrame.new(1.4, -1.0, -0.87)).Position, 0.05, ModelKit.Neon(souls))

	-- Tombstone shoulders, moss and hanging vines.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder = P[prefix .. "Shoulder"]
		local slabCF = CFrame.new(shoulder + V(side * 0.25, 0.75, 0)) * CFrame.Angles(0, math.pi / 2, side * -0.3)
		kit:Part(prefix .. "UpperArm", V(1.0, 1.1, 0.28), slabCF, granite)
		kit:Part(prefix .. "UpperArm", V(0.28, 1.0, 1.0), slabCF * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.pi / 2, 0), granite, Enum.PartType.Cylinder)
		kit:Part(prefix .. "UpperArm", V(0.08, 0.55, 0.04), slabCF * CFrame.new(0, 0.2, -0.16), engraving)
		kit:Part(prefix .. "UpperArm", V(0.4, 0.08, 0.04), slabCF * CFrame.new(0, 0.32, -0.16), engraving)
		kit:Runes(prefix .. "UpperArm", slabCF * CFrame.new(0, -0.25, -0.15), 0.6, 0.18, 2, souls)
		kit:Ellipsoid(prefix .. "UpperArm", V(1.1, 0.3, 1.0), CFrame.new(shoulder + V(0, 0.3, 0)), "Moss")
		for i = 0, 2 do
			local top = shoulder + V(side * (0.2 + i * 0.2), 0.1, -0.35 + i * 0.3)
			kit:Rod(prefix .. "UpperArm", top, top + V(side * 0.05, -1.1 - i * 0.3, -0.1), 0.06, vine)
		end
		-- Huge fists wrapped in chain.
		local hand = P[prefix .. "Hand"]
		kit:Part(prefix .. "Forearm", V(1.15, 1.0, 1.15), CFrame.new(hand - V(0, 0.35, 0)), stone)
		for i = -1, 1 do
			kit:Part(prefix .. "Forearm", V(0.32, 0.3, 0.3), CFrame.new(hand + V(i * 0.35, -0.7, -0.45)), granite)
		end
		kit:Chain(prefix .. "Forearm", P[prefix .. "Elbow"] + V(-0.45, -0.3, -0.46), hand + V(0.45, 0.4, -0.47), 0.26, "Rust")
	end
	kit:Ellipsoid("Chest", V(2.2, 0.35, 1.2), C * CFrame.new(-0.2, 1.15, 0.2), "Moss")

	-- Head: heavy brow, stone horns, one cyclopean eye.
	local H = F.Head
	kit:Part("Head", V(1.05, 0.25, 0.4), H * CFrame.new(0, 0.28, -0.4), stone)
	local eye = kit:Ball("Head", 0.36, H * CFrame.new(0, 0, -0.45), ModelKit.Neon(def.Appearance.Eyes))
	eye.Name = "Eye"
	kit:Light(eye, def.Appearance.Eyes, 6, 2.5)
	kit:Emit(eye, "Wisps", def.Appearance.Eyes, { Rate = 5 })
	for _, side in { -1, 1 } do
		kit:Spike("Head", (H * CFrame.new(side * 0.4, 0.35, 0)).Position, (H * CFrame.new(side * 0.65, 0.8, 0.1)).Position, 0.22, granite)
	end

	-- Bell tower rising from the back.
	local towerBase = (C * CFrame.new(0, 0.9, 0.95)).Position
	kit:Part("Chest", V(0.8, 0.9, 0.8), CFrame.new(towerBase + V(0, 0.35, 0)), granite)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			kit:Part("Chest", V(0.14, 0.6, 0.14), CFrame.new(towerBase + V(x * 0.32, 1.1, z * 0.32)), granite)
		end
	end
	kit:Part("Chest", V(0.95, 0.14, 0.95), CFrame.new(towerBase + V(0, 1.45, 0)), granite)
	kit:Spike("Chest", towerBase + V(0, 1.5, 0), towerBase + V(0, 2.05, 0), 0.7, "Slate", 3)
	kit:Ellipsoid("Chest", V(0.4, 0.45, 0.4), CFrame.new(towerBase + V(0, 1.1, 0)), "Rust")
	local candle = kit:Part("Chest", V(0.1, 0.18, 0.1), CFrame.new(towerBase + V(0.3, 0.9, -0.3)), ModelKit.Neon(souls))
	kit:Emit(candle, "Flames", souls, { Rate = 8, Size = 0.25 })

	-- Stone feet, dust and soul wisps.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Part(prefix .. "Shin", V(1.0, 0.4, 1.35), CFrame.new(P[prefix .. "Foot"] + V(0, 0.2, -0.2)), stone)
		kit:Part(prefix .. "Thigh", V(1.0, 0.5, 1.0), CFrame.new(P[prefix .. "Knee"] + V(0, 0.05, -0.1)), granite)
	end
	kit:Emit(rig.Hips, "Mist", rgb(90, 90, 96), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 3 })
	kit:Emit(rig.Chest, "Spectral", souls, { Rate = 6, Size = 0.35 })
end
