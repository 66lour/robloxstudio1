--!strict
-- Ancient Pumpkin Lord: a towering, blazing scarecrow. Stilt legs, a patched
-- burlap coat bursting with straw, a wooden crossbar through the shoulders,
-- carved jack-o'-lantern pauldrons, and for a head a flaming skull crowned by
-- the shattered shell of an ancient pumpkin. Carries a great scythe and a
-- lantern; a crow keeps watch on the crossbar.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

local function pumpkin(kit: ModelKit.Kit, parent: string, center: CFrame, size: Vector3, glow: Color3, faceDirection: Vector3?)
	local orange = { Material = Enum.Material.SmoothPlastic, Color = rgb(222, 110, 24) }
	local rib = { Material = Enum.Material.SmoothPlastic, Color = rgb(176, 78, 16) }
	kit:Ellipsoid(parent, size, center, orange)
	for i = 0, 2 do
		kit:Ellipsoid(parent, V(size.X * 0.35, size.Y * 1.02, size.Z * 0.35), center * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(size.X * 0.32, 0, 0), rib)
		kit:Ellipsoid(parent, V(size.X * 0.35, size.Y * 1.02, size.Z * 0.35), center * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(-size.X * 0.32, 0, 0), rib)
	end
	kit:Horn(parent, (center * CFrame.new(0, size.Y * 0.45, 0)).Position, V(0.2, 1, 0), size.Y * 0.35, 0.12, 0.8, V(0, 0, 1), "Wood", 2)
	if faceDirection then
		-- Carved face: two triangle eyes and a jagged grin, lit from inside.
		local face = ModelKit.LookAt(center.Position, center.Position + faceDirection) * CFrame.new(0, 0, -size.Z * 0.47)
		local neon = ModelKit.Neon(glow)
		for _, side in { -1, 1 } do
			kit:Part(parent, V(size.X * 0.2, size.Y * 0.16, 0.06), face * CFrame.new(side * size.X * 0.18, size.Y * 0.12, 0) * CFrame.Angles(0, 0, side * 0.5), neon)
		end
		for i = -2, 2 do
			kit:Part(parent, V(size.X * 0.1, size.Y * (if i % 2 == 0 then 0.12 else 0.07), 0.06), face * CFrame.new(i * size.X * 0.1, -size.Y * 0.16, 0), neon)
		end
	end
end

return function(kit: ModelKit.Kit, def: any)
	local flame: Color3 = def.Appearance.Aura
	local burlap = "Burlap"
	local darkBurlap = ModelKit.Tint("Burlap", { Color = rgb(78, 58, 40) })
	local patch = ModelKit.Tint("Burlap", { Color = rgb(96, 88, 58) })
	local rope = ModelKit.Tint("Burlap", { Color = rgb(150, 124, 80) })

	local rig = kit:Rig({
		Legs = { Thigh = 1.5, Shin = 1.6, Spacing = 0.4, Width = 0.28, Style = "Wood" },
		Hips = { Size = V(1.1, 0.5, 0.6), Style = burlap },
		Chest = { Size = V(1.4, 1.8, 0.75), Style = burlap, Lean = 0.12, Round = true, Fat = 1.08 },
		Arms = { Upper = 1.3, Fore = 1.3, Width = 0.3, ShoulderX = 1.1, Style = burlap, ForeStyle = darkBurlap },
		Head = { Size = V(0.9, 0.95, 0.95), Style = "Hidden", Neck = 0.4 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Scarecrow frame: shoulder crossbar and the post up the spine.
	kit:Rod("Chest", (C * CFrame.new(-1.75, 0.55, 0.15)).Position, (C * CFrame.new(1.75, 0.55, 0.15)).Position, 0.22, "Wood")
	kit:Rod("Head", P.Neck - V(0, 0.05, 0), P.Neck + V(0, 0.55, 0), 0.24, "Wood")

	-- Patched burlap coat stuffed with straw, a rope belt and a long ragged tail.
	for _, offset in { V(-0.45, 0.3, -0.42), V(0.35, -0.35, -0.42) } do
		kit:Part("Chest", V(0.45, 0.45, 0.05), C * CFrame.new(offset) * CFrame.Angles(0, 0, 0.2), patch)
		kit:Rod("Chest", (C * CFrame.new(offset + V(-0.22, 0.2, -0.03))).Position, (C * CFrame.new(offset + V(0.22, -0.2, -0.03))).Position, 0.03, rope)
	end
	kit:Part("Hips", V(1.2, 0.14, 0.7), CFrame.new(P.Waist - V(0, 0.08, 0)), rope)
	kit:Robe("Hips", P.Waist, 0.62, 0.95, 1.9, 9, darkBurlap)
	kit:Strips("Chest", (C * CFrame.new(-0.4, 0.95, -0.35)).Position, (C * CFrame.new(0.4, 0.95, -0.35)).Position, 5, 0.25, 0.45, 0.03, "Straw", -1.2)
	kit:Strips("Hips", P.Waist + V(-0.5, -0.05, -0.36), P.Waist + V(0.5, -0.05, -0.36), 6, 0.3, 0.55, 0.03, "Straw")
	kit:Cape("Chest", P.Back + V(0, 0.45, 0.1), 1.4, 3.0, 3, darkBurlap)

	-- Carved jack-o'-lantern pauldrons.
	for _, side in { -1, 1 } do
		local shoulder = P[if side < 0 then "LeftShoulder" else "RightShoulder"]
		pumpkin(kit, if side < 0 then "LeftUpperArm" else "RightUpperArm", CFrame.new(shoulder + V(side * 0.2, 0.3, 0)), V(1.0, 0.8, 1.0), flame, V(side, 0, -0.6))
	end

	-- Sleeves with straw cuffs, twig fingers, vines winding up the arms.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local elbow, hand = P[prefix .. "Elbow"], P[prefix .. "Hand"]
		kit:Strips(prefix .. "Forearm", hand + V(-0.18, 0.1, -0.16), hand + V(0.18, 0.1, -0.16), 3, 0.25, 0.4, 0.03, "Straw")
		for i = -1, 1 do
			kit:Horn(prefix .. "Forearm", hand + V(i * 0.08, 0, 0), V(i * 0.3, -1, -0.3), 0.5, 0.06, 0.6, V(1, 0, 0), "DeadWood", 2)
		end
		for i = 0, 3 do
			local a = elbow + V(math.cos(i * 1.6) * 0.2, 0.5 - i * 0.35, math.sin(i * 1.6) * 0.2)
			local b = elbow + V(math.cos(i * 1.6 + 1.6) * 0.2, 0.15 - i * 0.35, math.sin(i * 1.6 + 1.6) * 0.2)
			kit:Rod(prefix .. "Forearm", a, b, 0.06, "Moss")
		end
	end

	-- Flaming charred skull inside the shattered shell of an ancient pumpkin.
	local H = F.Head
	local skull = kit:Ellipsoid("Head", V(0.85, 0.85, 0.95), H * CFrame.new(0, 0.05, 0), "CharredBone")
	kit:Part("Head", V(0.6, 0.3, 0.45), H * CFrame.new(0, -0.28, -0.2), "CharredBone")
	kit:Eyes("Head", H * CFrame.new(0, 0.0, -0.45), 0.36, V(0.16, 0.12, 0.05), def.Appearance.Eyes)
	local jaw = kit:Segment("Jaw", "Head", "Jaw", (H * CFrame.new(0, -0.3, 0.05)).Position, V(0.55, 0.14, 0.45), H * CFrame.new(0, -0.5, -0.18), "CharredBone")
	for i = -2, 2 do
		kit:Part(jaw, V(0.06, 0.09, 0.05), H * CFrame.new(i * 0.09, -0.42, -0.38), "OldBone")
	end
	kit:Fire(skull, flame, rgb(200, 30, 10), 3.2, 12)
	kit:Emit(skull, "Flames", flame, { Rate = 30, Size = 0.7, Offset = V(0, 0.35, 0) })
	kit:Emit(skull, "Embers", flame, { Rate = 16 })
	kit:Light(skull, flame, 14, 3)
	-- Jagged shards of the old pumpkin splayed around the burning skull.
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2 + 0.3
		local base = H * CFrame.new(math.cos(angle) * 0.46, 0.25, math.sin(angle) * 0.5)
		local shard = base * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(-0.55, 0, 0)
		local height = 0.38 + (i % 2) * 0.18
		kit:Part("Head", V(0.3, height, 0.07), shard * CFrame.new(0, height / 2, 0), { Material = Enum.Material.SmoothPlastic, Color = rgb(206, 98, 22) })
		kit:Spike("Head", (shard * CFrame.new(0, height, 0)).Position, (shard * CFrame.new(0, height + 0.25, 0)).Position, 0.1, { Material = Enum.Material.SmoothPlastic, Color = rgb(176, 78, 16) }, 1)
	end
	kit:Horn("Head", (H * CFrame.new(0.3, 0.5, 0.35)).Position, V(0.4, 1, 0.4), 1.1, 0.07, 2.4, V(0, 0, 1), "Moss", 5)
	kit:Horn("Head", (H * CFrame.new(-0.35, 0.45, 0.3)).Position, V(-0.5, 1, 0.2), 0.8, 0.06, -2, V(0, 0, 1), "Moss", 4)

	-- The great scythe and a hanging lantern.
	Armory.Scythe(kit, "RightForearm", P.RightHand, { Length = 5.4, Blade = 2.4, Haft = "DeadWood", Edge = "Rust", Glow = flame })
	Armory.Lantern(kit, "LeftForearm", P.LeftHand - V(0, 0.15, 0), 0.55, "DarkMetal", flame)

	-- A crow perched on the end of the crossbar.
	local perch = (C * CFrame.new(-1.6, 0.72, 0.15)).Position
	local crow = { Material = Enum.Material.SmoothPlastic, Color = rgb(18, 16, 22) }
	kit:Ellipsoid("Chest", V(0.3, 0.32, 0.55), CFrame.new(perch + V(0, 0.18, 0)) * CFrame.Angles(0.4, 0, 0), crow)
	kit:Ball("Chest", 0.22, perch + V(0, 0.4, -0.22), crow)
	kit:Spike("Chest", perch + V(0, 0.38, -0.32), perch + V(0, 0.34, -0.5), 0.08, "DarkGold", 1)
	kit:Part("Chest", V(0.04, 0.04, 0.03), CFrame.new(perch + V(0.07, 0.43, -0.3)), ModelKit.Neon(rgb(255, 40, 30)))
	kit:Part("Chest", V(0.25, 0.04, 0.4), CFrame.new(perch + V(0, 0.08, 0.35)) * CFrame.Angles(-0.4, 0, 0), crow)

	-- Stilt legs: wrapped poles, straw at the knees, boots of rotten leather.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local knee, foot = P[prefix .. "Knee"], P[prefix .. "Foot"]
		for i = 0, 3 do
			kit:Part(prefix .. "Shin", V(0.34, 0.1, 0.34), CFrame.new(knee - V(0, 0.3 + i * 0.35, 0)) * CFrame.Angles(0.15, i, 0.1), rope)
		end
		kit:Strips(prefix .. "Thigh", knee + V(-0.15, 0.1, -0.15), knee + V(0.15, 0.1, -0.15), 3, 0.2, 0.35, 0.03, "Straw")
		kit:Part(prefix .. "Shin", V(0.45, 0.35, 0.8), CFrame.new(foot + V(0, 0.17, -0.12)), "Leather")
	end

	kit:Emit(rig.Chest, "Embers", flame, { Rate = 10 })
	kit:Emit(rig.Hips, "Mist", rgb(60, 36, 20), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 3 })
end
