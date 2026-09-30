--!strict
-- Wraith Knight: an ethereal warrior in floating obsidian armor. The plates hang
-- apart from each other with nothing but blue spectral smoke between them: a
-- great helm with a glowing T-visor and a plume of ghost-fire, runed breastplate,
-- floating pauldrons and greaves, a spectral robe for legs, a tattered cloak and
-- a runed obsidian longsword.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local spirit: Color3 = def.Appearance.Aura
	local obsidian = "Obsidian"
	local silver = "Metal"
	local ghost = ModelKit.Ghost(spirit, 0.5)
	local faintGhost = ModelKit.Ghost(spirit, 0.72)

	local rig = kit:Rig({
		Hover = 2.4,
		Hips = { Size = V(1.3, 0.5, 0.85), Style = obsidian },
		Chest = { Size = V(2.0, 1.75, 1.15), Style = obsidian, Lean = 0.05 },
		Arms = { Upper = 1.15, Fore = 1.1, Width = 0.5, ShoulderX = 1.25, Drop = 0.3, Style = obsidian, Gap = 0.35 },
		Head = { Size = V(0.85, 1.0, 0.95), Style = obsidian, Neck = 0.3 },
	})
	local P, F = rig.P, rig.F

	-- Runed breastplate, keel and banded abdomen.
	kit:Plate("Chest", V(1.9, 1.25, 0.12), F.Chest * CFrame.new(0, 0.15, -0.6), obsidian, silver, spirit, 3)
	kit:Part("Chest", V(0.14, 1.3, 0.16), F.Chest * CFrame.new(0, 0.15, -0.68), silver)
	for i = 0, 1 do
		kit:Plate("Chest", V(1.7 - i * 0.15, 0.22, 0.14), F.Chest * CFrame.new(0, -0.62 - i * 0.24, -0.55), obsidian, silver)
	end
	kit:Ring("Chest", CFrame.new(P.Neck + V(0, 0.05, 0)), 0.45, 10, V(0.3, 0.2, 0.18), obsidian)
	-- Spectral core glowing through the gaps.
	local core = kit:Ball("Chest", 0.9, F.Chest * CFrame.new(0, 0, 0.1), ghost)
	core.Name = "SpectralCore"
	kit:Emit(core, "Smoke", spirit, { Rate = 7, Size = 0.9 })
	kit:Emit(core, "Spectral", spirit, { Rate = 8 })
	kit:Light(core, spirit, 12, 2)
	-- Spectral chain slung across the chest.
	kit:Chain("Chest", (F.Chest * CFrame.new(-0.9, 0.7, -0.66)).Position, (F.Chest * CFrame.new(0.85, -0.7, -0.64)).Position, 0.24, faintGhost)

	-- Great helm: T-visor, crest with a ghost-fire plume, back-swept spikes.
	local H = F.Head
	kit:Part("Head", V(0.92, 0.9, 0.12), H * CFrame.new(0, -0.02, -0.5), obsidian)
	kit:Part("Head", V(0.62, 0.07, 0.04), H * CFrame.new(0, 0.12, -0.57), ModelKit.Neon(def.Appearance.Eyes))
	kit:Part("Head", V(0.08, 0.42, 0.04), H * CFrame.new(0, -0.12, -0.57), ModelKit.Neon(def.Appearance.Eyes))
	kit:Light(rig.Head, def.Appearance.Eyes, 5, 2)
	local crest = kit:Part("Head", V(0.12, 0.32, 1.0), H * CFrame.new(0, 0.62, 0.02), silver)
	kit:Emit(crest, "Flames", spirit, { Rate = 22, Size = 0.55, Lifetime = 1 })
	for _, side in { -1, 1 } do
		kit:Horn("Head", (H * CFrame.new(side * 0.42, 0.25, 0.1)).Position, V(side * 0.35, 0.35, 1), 1.0, 0.14, 0.6, V(side, 0, 0), silver, 4)
		kit:Part("Head", V(0.08, 0.7, 0.8), H * CFrame.new(side * 0.47, -0.05, 0), silver)
	end

	-- Floating pauldrons: three stacked plates each, spiked, drifting above the arms.
	for index, side in { -1, 1 } do
		local shoulder = P[if side < 0 then "LeftShoulder" else "RightShoulder"]
		local pivot = shoulder + V(side * 0.15, 0.45, 0)
		local pauldron = kit:Segment(if side < 0 then "LeftPauldron" else "RightPauldron", "Chest", `Float{index}`, pivot, V(1.15, 0.28, 1.15), CFrame.new(pivot) * CFrame.Angles(0, 0, side * -0.35), obsidian)
		for layer = 1, 2 do
			kit:Part(pauldron, V(1.05 - layer * 0.12, 0.2, 1.05 - layer * 0.1), CFrame.new(pivot + V(side * layer * 0.12, -layer * 0.22, 0)) * CFrame.Angles(0, 0, side * -0.55), obsidian)
		end
		kit:Part(pauldron, V(1.2, 0.08, 1.2), CFrame.new(pivot + V(0, 0.02, 0)) * CFrame.Angles(0, 0, side * -0.35), silver)
		kit:SpikeRow(pauldron, pivot + V(side * 0.1, 0.12, -0.35), pivot + V(side * 0.1, 0.12, 0.35), 3, 0.7, V(side * 0.4, 1, 0), 0.16, silver)
		kit:Runes(pauldron, CFrame.new(pivot + V(side * 0.6, -0.1, 0)) * CFrame.Angles(0, side * -math.pi / 2, 0), 0.5, 0.18, 2, spirit)
	end

	-- Arms: floating vambraces joined by spectral limbs, clawed gauntlets.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder, elbow, hand = P[prefix .. "Shoulder"], P[prefix .. "Elbow"], P[prefix .. "Hand"]
		kit:Rod(prefix .. "UpperArm", shoulder, elbow, 0.28, ghost, true)
		kit:Rod(prefix .. "Forearm", elbow, hand, 0.24, ghost, true)
		kit:Part(prefix .. "Forearm", V(0.62, 0.3, 0.62), CFrame.new(elbow:Lerp(hand, 0.3)), silver)
		kit:Part(prefix .. "Forearm", V(0.5, 0.42, 0.45), CFrame.new(hand - V(0, 0.1, 0)), obsidian)
		for i = -1, 1 do
			kit:Spike(prefix .. "Forearm", hand + V(i * 0.14, -0.25, -0.1), hand + V(i * 0.16, -0.65, -0.3), 0.1, silver)
		end
		kit:Spike(prefix .. "Forearm", elbow + V(0, 0, 0.25), elbow + V(0, 0.2, 0.75), 0.14, silver)
	end

	-- Faulds, spectral robe for legs, and floating greaves where the legs would be.
	kit:Robe("Hips", P.Waist, 0.75, 0.95, 0.95, 8, obsidian, 0.8, false)
	kit:Robe("Hips", P.Waist - V(0, 0.3, 0), 0.6, 1.0, 2.1, 10, faintGhost)
	for index, side in { -1, 1 } do
		local pivot = V(side * 0.45, 1.75, 0)
		local greave = kit:Segment(if side < 0 then "LeftGreave" else "RightGreave", "Hips", `Float{index + 2}`, pivot, V(0.48, 1.1, 0.55), CFrame.new(side * 0.45, 1.05, 0), obsidian)
		kit:Part(greave, V(0.55, 0.4, 0.5), CFrame.new(side * 0.45, 1.65, -0.05), silver)
		kit:Spike(greave, V(side * 0.45, 1.65, -0.3), V(side * 0.45, 1.95, -0.7), 0.16, silver)
		kit:Part(greave, V(0.5, 0.25, 0.9), CFrame.new(side * 0.45, 0.35, -0.15), obsidian)
		kit:Runes(greave, CFrame.new(side * 0.45, 1.0, -0.28), 0.3, 0.3, 1, spirit)
	end

	-- Tattered cloak and runed obsidian longsword.
	kit:Cape("Chest", P.Back + V(0, 0.55, 0.12), 1.7, 2.9, 3, ModelKit.Tint("Cloth", { Color = rgb(16, 16, 22) }), silver)
	Armory.Sword(kit, "RightForearm", P.RightHand, V(0, -0.15, -1), {
		Length = 2.7,
		Width = 0.34,
		Blade = obsidian,
		Hilt = silver,
		Glow = spirit,
		Runes = true,
	})

	kit:Emit(rig.Hips, "Mist", spirit:Lerp(Color3.new(0, 0, 0), 0.5), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 4 })
end
