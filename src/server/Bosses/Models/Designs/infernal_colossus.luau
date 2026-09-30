--!strict
-- Infernal Colossus: a walking forge of obsidian and cooling lava. A roaring
-- furnace behind the grate in its chest, molten seams across every plate,
-- smoking chimneys on its shoulders, great forward-curving horns, an anvil for
-- a left fist and a forge hammer fused to the right. Embers and magma drip off
-- it constantly.

local Models = script.Parent.Parent
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local fire: Color3 = def.Appearance.Aura
	local rock = "ObsidianRough"
	local glass = "Obsidian"
	local lava = "Lava"
	local molten = ModelKit.Neon(rgb(255, 120, 30))

	local rig = kit:Rig({
		Legs = { Thigh = 1.05, Shin = 1.15, Spacing = 0.85, Width = 0.95, Style = rock },
		Hips = { Size = V(2.3, 0.9, 1.4), Style = rock },
		Chest = { Size = V(3.2, 2.5, 1.9), Style = rock, Lean = 0.25 },
		Arms = { Upper = 1.4, Fore = 1.7, Width = 0.95, ShoulderX = 2.15, Drop = 0.5, Style = rock },
		Head = { Size = V(1.1, 1.0, 1.1), Style = rock, Neck = 0 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Furnace: molten core behind a grate.
	local furnace = C * CFrame.new(0, 0, -0.9)
	kit:Part("Chest", V(1.9, 1.6, 0.2), furnace * CFrame.new(0, 0, 0.1), "BlackMetal")
	local core = kit:Part("Chest", V(1.6, 1.3, 0.12), furnace, lava)
	core.Name = "FurnaceCore"
	kit:Part("Chest", V(1.4, 1.1, 0.1), furnace * CFrame.new(0, 0, -0.04), molten)
	for i = -3, 3 do
		kit:Part("Chest", V(0.12, 1.5, 0.14), furnace * CFrame.new(i * 0.22, 0, -0.12), "BlackMetal")
	end
	kit:Part("Chest", V(1.95, 0.18, 0.2), furnace * CFrame.new(0, 0.8, -0.1), "DarkMetal")
	kit:Part("Chest", V(1.95, 0.18, 0.2), furnace * CFrame.new(0, -0.8, -0.1), "DarkMetal")
	kit:Fire(core, fire, rgb(120, 20, 0), 6, 14)
	kit:Emit(core, "Embers", fire, { Rate = 24, Size = 0.3 })
	kit:Light(core, fire, 18, 3)

	-- Molten seams and cracked-lava patches over the plates.
	for _, patch in { { V(-1.35, 0.6, -0.4), V(0.5, 0.9, 1.0) }, { V(1.4, -0.5, -0.2), V(0.5, 1.0, 1.2) }, { V(0.3, 1.05, 0.3), V(1.4, 0.45, 1.2) } } do
		kit:Part("Chest", patch[2], C * CFrame.new(patch[1]), lava)
	end
	for _, line in { { V(-1.5, 1.1, -0.96), V(-1.0, -0.3, -0.96) }, { V(1.1, 1.0, -0.96), V(1.5, 0.1, -0.96) }, { V(-0.6, -1.25, -0.96), V(0.7, -1.1, -0.96) } } do
		kit:Rod("Chest", (C * CFrame.new(line[1])).Position, (C * CFrame.new(line[2])).Position, 0.07, molten)
	end
	kit:SpikeRow("Chest", (C * CFrame.new(0, 1.2, 0.8)).Position, (C * CFrame.new(0, -1.0, 1.0)).Position, 6, 1.1, (C.Rotation * CFrame.new(0, 0.5, 1)).Position, 0.35, glass)

	-- Head: molten eyes, grille mouth, great horns.
	local H = F.Head
	kit:Part("Head", V(1.2, 0.3, 0.4), H * CFrame.new(0, 0.3, -0.45), glass)
	kit:Eyes("Head", H * CFrame.new(0, 0.05, -0.57), 0.5, V(0.22, 0.12, 0.05), def.Appearance.Eyes)
	kit:Part("Head", V(0.7, 0.12, 0.05), H * CFrame.new(0, -0.3, -0.57), molten)
	for i = -2, 2 do
		kit:Part("Head", V(0.06, 0.2, 0.06), H * CFrame.new(i * 0.14, -0.3, -0.6), "BlackMetal")
	end
	for _, side in { -1, 1 } do
		kit:Horn("Head", (H * CFrame.new(side * 0.5, 0.35, 0)).Position, V(side, 0.8, 0.2), 2.4, 0.42, -2.0, V(0, 0, side), glass, 7)
	end

	-- Chimney stacks pouring smoke and embers.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder = P[prefix .. "Shoulder"]
		kit:Part(prefix .. "UpperArm", V(1.5, 0.6, 1.5), CFrame.new(shoulder + V(side * 0.1, 0.45, 0)), rock)
		for index, offset in { V(side * 0.3, 0, 0.35), V(side * -0.2, 0, -0.1) } do
			local base = shoulder + V(0, 0.75, 0) + offset
			local height = 1.1 - index * 0.35
			local stack = kit:Part(prefix .. "UpperArm", V(height, 0.42, 0.42), CFrame.new(base + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), "DarkMetal", Enum.PartType.Cylinder)
			kit:Part(prefix .. "UpperArm", V(0.1, 0.5, 0.5), CFrame.new(base + V(0, height, 0)) * CFrame.Angles(0, 0, math.pi / 2), "BlackMetal", Enum.PartType.Cylinder)
			kit:Emit(stack, "Smoke", rgb(40, 34, 32), { Rate = 5, Size = 1.1, Offset = V(0, height / 2, 0) })
			kit:Emit(stack, "Embers", fire, { Rate = 6, Offset = V(0, height / 2, 0) })
		end
		kit:Rod(prefix .. "UpperArm", shoulder + V(side * 0.7, 0.2, -0.55), P[prefix .. "Elbow"] + V(side * 0.5, 0.2, -0.5), 0.07, molten)
	end

	-- Anvil fist (left) and forge hammer (right), dripping magma.
	local leftHand = P.LeftHand
	local anvil = kit:Part("LeftForearm", V(1.5, 1.1, 1.5), CFrame.new(leftHand - V(0, 0.45, 0)), "DarkMetal")
	kit:Part("LeftForearm", V(1.7, 0.3, 1.1), CFrame.new(leftHand - V(0, 0.05, 0)), "BlackMetal")
	kit:Spike("LeftForearm", leftHand + V(0.1, -0.05, -0.55), leftHand + V(0.1, -0.1, -1.4), 0.5, "BlackMetal")
	kit:Emit(anvil, "Drips", fire, { Rate = 6 })
	-- The right fist is a forge hammer fused to the arm: banded head, glowing runes.
	local hammerCF = CFrame.new(P.RightHand - V(0, 0.55, 0))
	local hammer = kit:Part("RightForearm", V(2.1, 1.3, 1.4), hammerCF, rock)
	hammer.Name = "HammerFist"
	for _, x in { -0.75, 0.75 } do
		kit:Part("RightForearm", V(0.22, 1.42, 1.52), hammerCF * CFrame.new(x, 0, 0), "BlackMetal")
	end
	for _, x in { -1.1, 1.1 } do
		kit:Part("RightForearm", V(0.15, 1.1, 1.2), hammerCF * CFrame.new(x, 0, 0), molten)
	end
	kit:Runes("RightForearm", hammerCF * CFrame.new(0, 0, -0.71), 1.1, 0.5, 3, fire)
	kit:Spike("RightForearm", (hammerCF * CFrame.new(0, -0.6, 0)).Position, (hammerCF * CFrame.new(0, -1.2, -0.2)).Position, 0.5, glass)
	kit:Emit(hammer, "Embers", fire, { Rate = 8 })
	kit:Emit(hammer, "Drips", fire, { Rate = 4 })

	-- Pillar legs with molten knees and clawed feet.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Part(prefix .. "Thigh", V(1.2, 0.6, 1.2), CFrame.new(P[prefix .. "Knee"] + V(0, 0.1, -0.1)), lava)
		kit:Part(prefix .. "Shin", V(1.25, 0.5, 1.6), CFrame.new(P[prefix .. "Foot"] + V(0, 0.25, -0.2)), rock)
		for i = -1, 1 do
			kit:Spike(prefix .. "Shin", P[prefix .. "Foot"] + V(i * 0.4, 0.2, -0.9), P[prefix .. "Foot"] + V(i * 0.45, 0.05, -1.35), 0.3, glass, 1)
		end
		kit:Emit(kit.Segments[prefix .. "Shin"], "Embers", fire, { Rate = 4 })
	end

	kit:Emit(rig.Hips, "Mist", rgb(70, 30, 20), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 3 })
end
