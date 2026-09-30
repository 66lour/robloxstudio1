--!strict
-- Plague Rat King: a hunched giant rat in a moth-eaten royal cloak and a crown
-- of rusted coins. Long snout, yellow incisors, glowing boils, rats clinging to
-- its shoulders, a knot of tails dragging behind and a plague censer pouring
-- green smoke.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local plague: Color3 = def.Appearance.Aura
	local fur = ModelKit.Tint("Fur", { Color = rgb(86, 74, 66) })
	local paleFur = ModelKit.Tint("Fur", { Color = rgb(128, 116, 104) })
	local skin = ModelKit.Tint("Flesh", { Color = rgb(196, 138, 132), Material = Enum.Material.SmoothPlastic })
	local royal = ModelKit.Tint("Cloth", { Color = rgb(74, 30, 86) })
	local tooth = { Material = Enum.Material.SmoothPlastic, Color = rgb(226, 196, 90) }

	local rig = kit:Rig({
		Legs = { Thigh = 1.0, Shin = 1.1, Spacing = 0.5, Width = 0.45, Style = fur, Round = true, Fat = 1.2 },
		Hips = { Size = V(1.5, 0.6, 1.0), Style = fur, Round = true },
		Chest = { Size = V(1.9, 1.6, 1.3), Style = fur, Lean = 0.65, Round = true, Fat = 1.15 },
		Arms = { Upper = 1.0, Fore = 1.1, Width = 0.38, ShoulderX = 1.15, Style = fur, Round = true },
		Head = { Size = V(0.9, 0.85, 1.0), Style = "Hidden", Neck = 0.05, Tilt = 0.4 },
	})
	local P, F = rig.P, rig.F

	-- Belly, glowing boils.
	kit:Ellipsoid("Chest", V(1.4, 1.3, 0.8), F.Chest * CFrame.new(0, -0.15, -0.5), paleFur)
	for _, offset in { V(-0.6, 0.4, -0.55), V(0.5, -0.2, -0.62), V(0.8, 0.5, 0.2), V(-0.3, -0.5, 0.6) } do
		kit:Ball("Chest", 0.16, F.Chest * CFrame.new(offset), ModelKit.Neon(plague))
	end

	-- Head: snout, whiskers, incisors, round ears and a crown of coins.
	local H = F.Head
	kit:Ellipsoid("Head", V(1.0, 0.85, 1.0), H * CFrame.new(0, 0.05, 0.1), fur)
	kit:Ellipsoid("Head", V(0.62, 0.5, 1.15), H * CFrame.new(0, -0.12, -0.55), fur)
	kit:Ball("Head", 0.2, H * CFrame.new(0, -0.08, -1.1), skin)
	for _, side in { -1, 1 } do
		for i = -1, 1 do
			local base = (H * CFrame.new(side * 0.22, -0.12, -0.95)).Position
			kit:Rod("Head", base, base + (H.Rotation * CFrame.new(side * 0.7, i * 0.15, 0.1)).Position, 0.025, paleFur)
		end
		local ear = kit:Part("Head", V(0.07, 0.55, 0.55), H * CFrame.new(side * 0.38, 0.48, 0.1) * CFrame.Angles(0, side * 0.4, side * -0.4), fur, Enum.PartType.Cylinder, "Ear")
		kit:Part(ear, V(0.08, 0.38, 0.38), H * CFrame.new(side * 0.38, 0.48, 0.1) * CFrame.Angles(0, side * 0.4, side * -0.4) * CFrame.new(side * -0.02, 0, 0), skin, Enum.PartType.Cylinder, "EarInner")
	end
	for _, side in { -1, 1 } do
		kit:Part("Head", V(0.1, 0.24, 0.07), H * CFrame.new(side * 0.06, -0.4, -1.0), tooth)
	end
	kit:Eyes("Head", H * CFrame.new(0, 0.12, -0.42), 0.5, V(0.1, 0.08, 0.05), def.Appearance.Eyes)
	local crownCF = H * CFrame.new(0, 0.42, 0.12)
	kit:Ring("Head", crownCF, 0.36, 10, V(0.2, 0.14, 0.1), "DarkGold")
	kit:Crown("Head", crownCF * CFrame.new(0, 0.05, 0), 0.36, 6, 0.38, 0.1, "Rust", 0.2)
	for i = 0, 2 do
		local angle = -math.pi / 2 + (i - 1) * 0.8
		kit:Ball("Head", 0.1, crownCF * CFrame.new(math.cos(angle) * 0.38, 0.02, math.sin(angle) * 0.38), ModelKit.Neon(if i == 1 then rgb(220, 30, 40) else plague))
	end

	-- Moth-eaten royal cloak with a fur mantle, and rats clinging on.
	kit:Ellipsoid("Chest", V(2.3, 0.55, 1.6), F.Chest * CFrame.new(0, 0.75, 0.05), ModelKit.Tint("Fur", { Color = rgb(214, 206, 190) }))
	kit:Cape("Chest", P.Back + V(0, 0.5, 0.2), 1.9, 2.6, 3, royal, "DarkGold")
	local ratSpots = { F.Chest * CFrame.new(-0.95, 0.95, 0.15), F.Chest * CFrame.new(0.8, 1.0, 0.35), F.Chest * CFrame.new(0.2, 0.5, 0.95), F.Chest * CFrame.new(-0.5, -0.1, 0.95) }
	for index, spot in ratSpots do
		local rat = spot * CFrame.Angles(0, index * 1.3, 0)
		kit:Ellipsoid("Chest", V(0.34, 0.26, 0.55), rat, fur)
		kit:Ellipsoid("Chest", V(0.2, 0.18, 0.28), rat * CFrame.new(0, 0.05, -0.35), fur)
		kit:Part("Chest", V(0.05, 0.04, 0.04), rat * CFrame.new(0.06, 0.1, -0.46), ModelKit.Neon(def.Appearance.Eyes))
		kit:Rod("Chest", (rat * CFrame.new(0, 0, 0.25)).Position, (rat * CFrame.new(0.1, -0.2, 0.75)).Position, 0.04, skin)
	end

	-- A knot of tails dragging behind.
	local knotCenter = P.Pelvis + V(0, -0.15, 0.7)
	kit:Ellipsoid("Hips", V(0.75, 0.55, 0.7), CFrame.new(knotCenter), skin)
	kit:Tail("Hips", "Tail", knotCenter + V(0, 0, 0.25), V(0, -0.35, 1), 3.2, 0.2, 5, skin, 0.9, V(1, 0, 0))
	kit:Tail("Hips", "TailB", knotCenter + V(-0.25, 0, 0.2), V(-0.7, -0.45, 0.8), 2.6, 0.16, 4, skin, 0.7, V(0, 1, 0))
	kit:Tail("Hips", "TailC", knotCenter + V(0.25, 0, 0.2), V(0.7, -0.45, 0.8), 2.4, 0.16, 4, skin, -0.7, V(0, 1, 0))
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		kit:Rod("Hips", knotCenter, knotCenter + V(math.cos(angle) * 0.6, math.sin(angle) * 0.35, 0.3), 0.07, skin)
	end

	-- Clawed pink hands; the right one swings a plague censer on a chain.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Ellipsoid(prefix .. "Forearm", V(0.36, 0.3, 0.34), CFrame.new(P[prefix .. "Hand"] - V(0, 0.08, 0)), skin)
		Armory.Claws(kit, prefix .. "Forearm", P[prefix .. "Hand"] - V(0, 0.18, 0), 3, 0.4, 0.26, tooth)
	end
	local censerTop = P.RightHand - V(0, 0.2, 0.15)
	local censer = censerTop - V(0, 1.0, 0.1)
	kit:Chain("RightForearm", censerTop, censer + V(0, 0.32, 0), 0.16, "Rust")
	local ball = kit:Ball("RightForearm", 0.6, censer, "Rust")
	ball.Name = "Censer"
	kit:Part("RightForearm", V(0.64, 0.08, 0.64), CFrame.new(censer), ModelKit.Neon(plague))
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		local out = V(math.cos(angle), (i % 2) * 0.5 - 0.25, math.sin(angle)).Unit
		kit:Spike("RightForearm", censer + out * 0.28, censer + out * 0.55, 0.1, "Rust", 1)
	end
	kit:Emit(ball, "Smoke", plague, { Rate = 9, Size = 0.8 })
	kit:Emit(ball, "Embers", plague, { Rate = 6 })
	kit:Light(ball, plague, 9, 2)

	-- Rat feet.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Ellipsoid(prefix .. "Shin", V(0.45, 0.2, 0.8), CFrame.new(P[prefix .. "Foot"] + V(0, 0.1, -0.25)), skin)
		Armory.Claws(kit, prefix .. "Shin", P[prefix .. "Foot"] + V(0, 0.2, -0.55), 3, 0.25, 0.3, tooth)
	end

	kit:Emit(rig.Hips, "Mist", plague:Lerp(Color3.new(0, 0, 0), 0.45), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 4 })
	kit:Emit(rig.Head, "Flies", rgb(26, 24, 16), { Rate = 8 })
end
