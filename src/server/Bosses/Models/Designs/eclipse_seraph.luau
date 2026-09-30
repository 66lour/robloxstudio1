--!strict
-- The Eclipse Seraph: heaven's herald fallen to the black sun. Six dark wings
-- edged in gold, obsidian armor laced with golden filigree, a faceless helm
-- with a single burning slit, and behind its head an eclipse: a black disc
-- ringed by a golden corona. It floats above the ground in flowing robes and
-- wields a spear of black and gold light.

local Models = script.Parent.Parent
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local corona: Color3 = def.Appearance.Aura
	local obsidian = "Obsidian"
	local gold = "Gold"
	local feather = { Material = Enum.Material.Glass, Color = rgb(22, 18, 28) }
	local robe = ModelKit.Tint("Cloth", { Color = rgb(24, 20, 30) })
	local light = ModelKit.Neon(corona)

	local rig = kit:Rig({
		Hover = 3.0,
		Hips = { Size = V(1.2, 0.5, 0.8), Style = obsidian },
		Chest = { Size = V(1.8, 1.8, 1.0), Style = obsidian, Lean = 0.05 },
		Arms = { Upper = 1.25, Fore = 1.3, Width = 0.4, ShoulderX = 1.15, Style = obsidian },
		Head = { Size = V(0.8, 1.0, 0.9), Style = "Hidden", Neck = 0.25 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Obsidian armor with golden filigree.
	kit:Plate("Chest", V(1.7, 1.5, 0.12), C * CFrame.new(0, 0.1, -0.55), obsidian, gold, corona, 3)
	for _, side in { -1, 1 } do
		kit:Rod("Chest", (C * CFrame.new(side * 0.8, 0.85, -0.63)).Position, (C * CFrame.new(side * 0.15, -0.8, -0.63)).Position, 0.05, gold)
		local shoulder = P[if side < 0 then "LeftShoulder" else "RightShoulder"]
		kit:Ellipsoid(if side < 0 then "LeftUpperArm" else "RightUpperArm", V(0.95, 0.5, 0.95), CFrame.new(shoulder + V(side * 0.1, 0.18, 0)) * CFrame.Angles(0, 0, side * -0.3), obsidian)
		kit:Ring(if side < 0 then "LeftUpperArm" else "RightUpperArm", CFrame.new(shoulder + V(side * 0.1, 0.2, 0)) * CFrame.Angles(0, 0, side * -0.3), 0.46, 10, V(0.2, 0.08, 0.08), gold)
		kit:Spike(if side < 0 then "LeftUpperArm" else "RightUpperArm", shoulder + V(side * 0.3, 0.35, 0), shoulder + V(side * 0.8, 0.9, 0.2), 0.16, gold)
		local prefix = if side < 0 then "Left" else "Right"
		kit:Part(prefix .. "Forearm", V(0.5, 0.7, 0.5), CFrame.new(P[prefix .. "Hand"] + V(0, 0.3, 0)), gold)
		kit:Part(prefix .. "Forearm", V(0.4, 0.35, 0.35), CFrame.new(P[prefix .. "Hand"] - V(0, 0.1, 0)), obsidian)
	end
	kit:Ring("Chest", CFrame.new(P.Neck + V(0, 0.02, 0)), 0.42, 10, V(0.28, 0.2, 0.14), gold)

	-- Faceless helm with a burning slit; the eclipse behind it.
	local H = F.Head
	kit:Ellipsoid("Head", V(0.82, 1.05, 0.9), H * CFrame.new(0, 0.05, 0), obsidian)
	kit:Part("Head", V(0.08, 0.6, 0.05), H * CFrame.new(0, 0.0, -0.44), ModelKit.Neon(def.Appearance.Eyes))
	kit:Part("Head", V(0.5, 0.06, 0.05), H * CFrame.new(0, 0.15, -0.43), ModelKit.Neon(def.Appearance.Eyes))
	kit:Crown("Head", H * CFrame.new(0, 0.45, 0.05), 0.3, 5, 0.45, 0.08, gold, 0.35)
	local eclipse = H * CFrame.new(0, 0.25, 0.75)
	kit:Part("Head", V(0.12, 2.0, 2.0), eclipse * CFrame.Angles(0, math.pi / 2, 0), obsidian, Enum.PartType.Cylinder)
	kit:Ring("Head", eclipse * CFrame.Angles(math.pi / 2, 0, 0), 1.08, 20, V(0.22, 0.24, 0.12), light)
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local base = (eclipse * CFrame.new(math.cos(angle) * 1.15, math.sin(angle) * 1.15, 0.02)).Position
		local tip = (eclipse * CFrame.new(math.cos(angle) * (1.6 + (i % 2) * 0.4), math.sin(angle) * (1.6 + (i % 2) * 0.4), 0.02)).Position
		kit:Spike("Head", base, tip, 0.12, light)
	end
	kit:Light(rig.Head, corona, 14, 2.5)

	-- Six dark, gold-edged wings.
	for pair = 1, 3 do
		for _, side in { -1, 1 } do
			local root = (C * CFrame.new(side * 0.35, 0.7 - pair * 0.45, 0.55)).Position
			local wing = kit:Wing("Chest", side, root, 3.2 - pair * 0.55, 2.2 - pair * 0.35, "Feather", gold, feather, pair)
			kit:Emit(wing, "Wisps", corona, { Rate = 3, Size = 0.25 })
		end
	end

	-- Flowing robe beneath.
	kit:Robe("Hips", P.Waist + V(0, 0.05, 0), 0.65, 1.3, 2.7, 12, robe)
	kit:Ring("Hips", CFrame.new(P.Waist + V(0, 0.02, 0)), 0.66, 12, V(0.3, 0.14, 0.1), gold)
	kit:Part("Hips", V(0.5, 2.2, 0.06), CFrame.new(P.Waist + V(0, -1.1, -0.72)), ModelKit.Tint("Cloth", { Color = rgb(150, 110, 40) }))
	kit:Runes("Hips", CFrame.new(P.Waist + V(0, -0.8, -0.76)), 0.35, 0.3, 1, corona)

	-- Spear of black and gold light.
	local butt = P.RightHand + V(0, -1.4, 0.8)
	local head = P.RightHand + V(0, 0.9, -2.2)
	kit:Rod("RightForearm", butt, head, 0.14, obsidian, true)
	kit:Rod("RightForearm", P.RightHand + V(0, -0.2, 0.1), P.RightHand + V(0, 0.2, -0.3), 0.2, gold, true)
	local tip = head + (head - butt).Unit * 1.6
	local blade = kit:Part("RightForearm", V(0.45, 0.08, 1.6), ModelKit.Along(head, tip), light)
	kit:Spike("RightForearm", head, tip + (head - butt).Unit * 0.4, 0.3, gold)
	for _, sign in { -1, 1 } do
		kit:Spike("RightForearm", head, head + V(sign * 0.6, 0.35, 0.2), 0.14, gold)
	end
	kit:Trail(blade, V(0, 0, 0.8), V(0, 0, -0.8), corona, 0.35)

	kit:Emit(rig.Chest, "Void", rgb(20, 14, 24), { Rate = 4 })
	kit:Emit(rig.Hips, "Wisps", corona, { Rate = 6, Offset = V(0, -1.8, 0) })
end
