--!strict
-- Crypt Lich: a skeletal archmage floating in layered, gold-trimmed robes. A
-- tall spiked crown, a high flared collar, cyan soul-fire pouring from its eye
-- sockets, a black phylactery amulet, a chained grimoire, a staff crowned with
-- a phylactery gem, and shards of its soul orbiting it in cyan trails.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local soul: Color3 = def.Appearance.Aura
	local robe = ModelKit.Tint("Cloth", { Color = rgb(48, 30, 66) })
	local innerRobe = ModelKit.Tint("Cloth", { Color = rgb(26, 18, 36) })
	local gold = "Gold"
	local bone = "OldBone"

	local rig = kit:Rig({
		Hover = 2.6,
		Hips = { Size = V(1.2, 0.5, 0.8), Style = innerRobe },
		Chest = { Size = V(1.6, 1.7, 0.95), Style = robe, Lean = 0.08 },
		Arms = { Upper = 1.2, Fore = 1.2, Width = 0.34, ShoulderX = 1.05, Style = robe, ForeStyle = bone },
		Head = { Size = V(0.9, 1.0, 1.0), Style = "Hidden", Neck = 0.25 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Layered robes floating above the ground, trimmed in gold.
	kit:Robe("Hips", P.Waist + V(0, 0.1, 0), 0.7, 1.35, 2.5, 12, robe)
	kit:Robe("Hips", P.Waist - V(0, 0.2, 0), 0.6, 1.05, 2.3, 10, innerRobe, 0.8, false)
	kit:Ring("Hips", CFrame.new(P.Waist + V(0, 0.05, 0)), 0.72, 12, V(0.34, 0.16, 0.1), gold)
	kit:Rod("Chest", (C * CFrame.new(0, 0.85, -0.5)).Position, (C * CFrame.new(0, -0.85, -0.5)).Position, Vector2.new(0.18, 0.05), gold)
	for _, side in { -1, 1 } do
		kit:Rod("Chest", (C * CFrame.new(side * 0.25, 0.85, -0.5)).Position, (C * CFrame.new(side * 0.55, -0.85, -0.5)).Position, Vector2.new(0.1, 0.04), gold)
	end
	kit:Cape("Chest", P.Back + V(0, 0.55, 0.1), 1.6, 3.2, 3, innerRobe, gold)

	-- High flared collar behind the head.
	for i = 0, 6 do
		local t = (i / 6 - 0.5) * 2.4
		local base = (C * CFrame.new(math.sin(t) * 0.55, 0.85, math.cos(t) * 0.35 + 0.1)).Position
		local tip = base + (C.Rotation * CFrame.new(math.sin(t) * 0.45, 1.25, math.cos(t) * 0.35 + 0.1)).Position
		kit:Part("Chest", V(0.34, (tip - base).Magnitude, 0.05), ModelKit.Along(base, tip) * CFrame.Angles(math.pi / 2, 0, 0), robe)
		kit:Rod("Chest", base, tip, 0.05, gold)
	end

	-- Phylactery amulet on gold chains.
	local amulet = C * CFrame.new(0, 0.1, -0.55)
	kit:Ring("Chest", amulet * CFrame.Angles(math.pi / 2, 0, 0), 0.26, 10, V(0.1, 0.1, 0.14), gold)
	local gem = kit:Ball("Chest", 0.36, amulet * CFrame.new(0, 0, -0.05), "Obsidian")
	gem.Name = "Phylactery"
	kit:Ball("Chest", 0.14, amulet * CFrame.new(0, 0, -0.2), ModelKit.Neon(soul))
	kit:Light(gem, soul, 8, 2)
	for _, side in { -1, 1 } do
		kit:Chain("Chest", (C * CFrame.new(side * 0.6, 0.75, -0.5)).Position, (amulet * CFrame.new(side * 0.2, 0.2, 0)).Position, 0.14, gold)
	end

	-- Crowned skull with soul-fire eyes.
	local H = F.Head
	kit:Ellipsoid("Head", V(0.9, 0.85, 1.0), H * CFrame.new(0, 0.12, 0.05), bone)
	kit:Part("Head", V(0.66, 0.3, 0.5), H * CFrame.new(0, -0.25, -0.22), bone)
	for _, side in { -1, 1 } do
		kit:Ball("Head", 0.28, H * CFrame.new(side * 0.2, -0.04, -0.4), { Material = Enum.Material.SmoothPlastic, Color = rgb(8, 8, 12) })
		local eye = kit:Part("Head", V(0.12, 0.09, 0.05), H * CFrame.new(side * 0.2, -0.04, -0.52), ModelKit.Neon(def.Appearance.Eyes))
		kit:Emit(eye, "Flames", soul, { Rate = 14, Size = 0.22, Lifetime = 0.6 })
	end
	kit:Light(rig.Head, soul, 6, 2)
	for i = -2, 2 do
		kit:Part("Head", V(0.07, 0.1, 0.06), H * CFrame.new(i * 0.1, -0.43, -0.42), bone)
	end
	kit:Segment("Jaw", "Head", "Jaw", (H * CFrame.new(0, -0.35, 0.05)).Position, V(0.6, 0.14, 0.48), H * CFrame.new(0, -0.52, -0.2), bone)
	local crownCF = H * CFrame.new(0, 0.42, 0.05)
	kit:Ring("Head", crownCF, 0.42, 12, V(0.24, 0.18, 0.08), gold)
	kit:Crown("Head", crownCF * CFrame.new(0, 0.08, 0), 0.42, 7, 0.7, 0.1, gold, 0.1)
	for i = 0, 6 do
		local angle = i / 7 * math.pi * 2
		kit:Ball("Head", 0.09, crownCF * CFrame.new(math.cos(angle) * 0.44, 0, math.sin(angle) * 0.44), ModelKit.Neon(soul))
	end

	-- Bell sleeves, skeletal hands, a phylactery staff and a chained grimoire.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Robe(prefix .. "UpperArm", P[prefix .. "Shoulder"] + V(0, 0.1, 0), 0.26, 0.55, 1.5, 7, robe, 1, true)
		local hand = P[prefix .. "Hand"]
		for i = -1.5, 1.5 do
			local base = hand + V(i * 0.07, -0.05, -0.02)
			kit:Rod(prefix .. "Forearm", base, base + V(i * 0.03, -0.35, -0.12), 0.05, bone)
		end
	end
	Armory.Staff(kit, "RightForearm", P.RightHand, {
		Length = 5.0,
		Haft = "BlackMetal",
		Orb = ModelKit.Tint("Obsidian", {}),
		OrbSize = 0.55,
		Glow = soul,
		Prongs = 4,
	})
	local bookCenter = P.Waist + V(-0.85, -0.55, -0.25)
	kit:Part("Hips", V(0.55, 0.75, 0.2), CFrame.new(bookCenter) * CFrame.Angles(0.1, 0.4, 0.15), "Leather")
	kit:Part("Hips", V(0.5, 0.7, 0.16), CFrame.new(bookCenter + V(0.02, 0, 0)) * CFrame.Angles(0.1, 0.4, 0.15), { Material = Enum.Material.SmoothPlastic, Color = rgb(220, 206, 170) })
	kit:Runes("Hips", CFrame.new(bookCenter) * CFrame.Angles(0.1, 0.4, 0.15) * CFrame.new(0, 0, -0.11), 0.3, 0.3, 1, soul)
	kit:Chain("Hips", P.Waist + V(-0.6, 0, -0.35), bookCenter + V(0, 0.38, 0), 0.14, gold)

	-- Orbiting soul shards with trails, soul mist beneath.
	kit:Orbit("Chest", C.Position + V(0, -0.1, 0), 2.1, 3, 0.38, ModelKit.Neon(soul), soul, 0.4)
	kit:Emit(rig.Hips, "Mist", soul:Lerp(Color3.new(0, 0, 0), 0.5), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 5 })
	kit:Emit(rig.Chest, "Spectral", soul, { Rate = 6 })
end
