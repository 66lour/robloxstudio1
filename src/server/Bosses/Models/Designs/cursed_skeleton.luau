--!strict
-- Cursed Skeleton: a soldier buried without rites. Bare bones and a ribcage
-- holding a green soul-flame, a rusted horned half-helm and pauldron, a cracked
-- shield, a notched sword, a tattered cloak and grave mist at its feet.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local soul: Color3 = def.Appearance.Aura
	local bone = "Bone"
	local dark = { Material = Enum.Material.SmoothPlastic, Color = rgb(12, 10, 10) }
	local cloth = ModelKit.Tint("Cloth", { Color = rgb(70, 26, 28) })

	local rig = kit:Rig({
		Legs = { Thigh = 1.25, Shin = 1.25, Spacing = 0.42, Width = 0.2, Style = bone },
		Hips = { Size = V(1.2, 0.4, 0.6), Style = "Hidden" },
		Chest = { Size = V(1.6, 1.8, 0.9), Style = "Hidden", Lean = 0.06 },
		Arms = { Upper = 1.2, Fore = 1.15, Width = 0.19, ShoulderX = 0.95, Drop = 0.2, Style = bone },
		Head = { Size = V(0.95, 1.0, 1.05), Style = "Hidden", Neck = 0.3 },
	})
	local P, F = rig.P, rig.F

	-- Pelvis and lumbar spine.
	for _, side in { -1, 1 } do
		kit:Part("Hips", V(0.5, 0.42, 0.1), CFrame.new(P.Pelvis + V(side * 0.35, 0.05, 0.05)) * CFrame.Angles(0, side * 0.5, side * 0.25), bone)
		kit:Ball("Hips", 0.26, P[if side < 0 then "LeftHip" else "RightHip"], bone)
	end
	kit:Part("Hips", V(0.3, 0.35, 0.12), CFrame.new(P.Pelvis + V(0, 0, 0.25)), bone)
	kit:Rod("Hips", P.Pelvis + V(-0.3, -0.12, -0.2), P.Pelvis + V(0.3, -0.12, -0.2), 0.1, bone)
	for i = 0, 2 do
		kit:Part("Hips", V(0.22, 0.12, 0.22), CFrame.new(P.Waist + V(0, -0.05 + i * 0.1, 0.18)), bone)
	end
	-- Belt and tattered loincloth.
	kit:Part("Hips", V(1.3, 0.14, 0.72), CFrame.new(P.Pelvis + V(0, 0.12, 0)), "Leather")
	kit:Strips("Hips", P.Pelvis + V(-0.45, 0.06, -0.37), P.Pelvis + V(0.45, 0.06, -0.37), 4, 0.5, 0.95, 0.05, cloth)
	kit:Strips("Hips", P.Pelvis + V(-0.45, 0.06, 0.37), P.Pelvis + V(0.45, 0.06, 0.37), 4, 0.4, 0.8, 0.05, cloth)

	-- Ribcage with the soul-flame inside.
	kit:Ribcage("Chest", F.Chest * CFrame.new(0, 0.2, 0), 1.35, 1.2, 0.75, 5, bone, 0.08)
	for _, side in { -1, 1 } do
		local shoulder = P[if side < 0 then "LeftShoulder" else "RightShoulder"]
		kit:Rod("Chest", (F.Chest * CFrame.new(0, 0.8, -0.35)).Position, shoulder, 0.09, bone)
		kit:Part("Chest", V(0.5, 0.55, 0.08), F.Chest * CFrame.new(side * 0.45, 0.45, 0.42) * CFrame.Angles(0, 0, side * 0.2), bone)
	end
	local core = kit:Ball("Chest", 0.45, F.Chest * CFrame.new(0, 0.15, 0.05), ModelKit.Neon(soul))
	core.Name = "SoulFlame"
	kit:Emit(core, "Flames", soul, { Rate = 18, Size = 0.5 })
	kit:Emit(core, "Wisps", soul, { Rate = 6 })
	kit:Light(core, soul, 10, 2.5)

	-- Skull, jaw and rusted horned half-helm.
	for i = 0, 2 do
		kit:Part("Head", V(0.2, 0.1, 0.2), CFrame.new(P.Neck + V(0, 0.06 + i * 0.1, 0.05)), bone)
	end
	kit:Ellipsoid("Head", V(0.95, 0.85, 1.05), F.Head * CFrame.new(0, 0.12, 0.05), bone)
	kit:Part("Head", V(0.7, 0.32, 0.5), F.Head * CFrame.new(0, -0.25, -0.22), bone)
	kit:Part("Head", V(0.8, 0.12, 0.2), F.Head * CFrame.new(0, 0.08, -0.43), bone)
	for _, side in { -1, 1 } do
		kit:Part("Head", V(0.2, 0.14, 0.35), F.Head * CFrame.new(side * 0.36, -0.12, -0.25), bone)
		kit:Ball("Head", 0.28, F.Head * CFrame.new(side * 0.2, -0.04, -0.4), dark)
	end
	kit:Eyes("Head", F.Head * CFrame.new(0, -0.04, -0.52), 0.4, V(0.12, 0.08, 0.05), def.Appearance.Eyes)
	kit:Part("Head", V(0.12, 0.16, 0.05), F.Head * CFrame.new(0, -0.22, -0.48), dark)
	for i = -2, 2 do
		kit:Part("Head", V(0.07, 0.1, 0.06), F.Head * CFrame.new(i * 0.1, -0.44, -0.43), bone)
	end
	local jaw = kit:Segment("Jaw", "Head", "Jaw", (F.Head * CFrame.new(0, -0.35, 0.05)).Position, V(0.62, 0.15, 0.5), F.Head * CFrame.new(0, -0.52, -0.2), bone)
	for i = -2, 2 do
		kit:Part(jaw, V(0.07, 0.09, 0.06), F.Head * CFrame.new(i * 0.1, -0.44, -0.41), bone)
	end
	kit:Ellipsoid("Head", V(1.04, 0.55, 1.12), F.Head * CFrame.new(0, 0.34, 0.05), "Rust")
	kit:Part("Head", V(0.12, 0.2, 1.0), F.Head * CFrame.new(0, 0.6, 0.05), "Rust")
	kit:Rod("Head", (F.Head * CFrame.new(0, 0.32, -0.56)).Position, (F.Head * CFrame.new(0, -0.1, -0.6)).Position, Vector2.new(0.1, 0.05), "Rust")
	for _, side in { -1, 1 } do
		kit:Horn("Head", (F.Head * CFrame.new(side * 0.45, 0.35, 0)).Position, V(side, 0.5, 0), 0.6, 0.13, 1.1, V(0, 0, side), "OldBone", 4)
	end

	-- Arms: joint knobs, twin forearm bones, finger bones.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local shoulder, elbow, hand = P[prefix .. "Shoulder"], P[prefix .. "Elbow"], P[prefix .. "Hand"]
		kit:Ball(prefix .. "UpperArm", 0.26, shoulder, bone)
		kit:Ball(prefix .. "Forearm", 0.2, elbow, bone)
		kit:Rod(prefix .. "Forearm", elbow + V(side * 0.07, -0.05, 0), hand + V(side * 0.07, 0.05, 0), 0.08, bone)
		kit:Part(prefix .. "Forearm", V(0.26, 0.2, 0.1), CFrame.new(hand - V(0, 0.08, 0)), bone)
		for i = -1.5, 1.5 do
			local base = hand + V(i * 0.06, -0.16, -0.02)
			kit:Rod(prefix .. "Forearm", base, base + V(i * 0.02, -0.28, -0.08), 0.045, bone)
		end
	end
	-- Rusted spiked pauldron on the left shoulder.
	kit:Ellipsoid("LeftUpperArm", V(0.78, 0.45, 0.78), CFrame.new(P.LeftShoulder + V(-0.08, 0.1, 0)) * CFrame.Angles(0, 0, 0.3), "Rust")
	for i = -1, 1 do
		kit:Spike("LeftUpperArm", P.LeftShoulder + V(-0.2, 0.25, i * 0.22), P.LeftShoulder + V(-0.45, 0.7, i * 0.3), 0.12, "Rust")
	end
	Armory.Shield(kit, "LeftForearm", P.LeftElbow:Lerp(P.LeftHand, 0.45) + V(-0.2, 0, 0), V(-1, 0, -0.3), 1.15, "DeadWood", "Rust", soul)
	kit:Rod("LeftForearm", P.LeftElbow:Lerp(P.LeftHand, 0.35) + V(-0.3, 0.2, -0.05), P.LeftElbow:Lerp(P.LeftHand, 0.35) + V(-0.95, 0.45, -0.3), 0.05, "DeadWood")
	Armory.Sword(kit, "RightForearm", P.RightHand + V(0, 0.05, 0), V(0, -0.2, -1), {
		Length = 2.1,
		Width = 0.28,
		Blade = "Rust",
		Hilt = "Leather",
		Serrated = true,
	})

	-- Legs: kneecaps, fibulas, feet, a broken shackle.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local knee, foot = P[prefix .. "Knee"], P[prefix .. "Foot"]
		kit:Ball(prefix .. "Shin", 0.24, knee + V(0, 0, -0.05), bone)
		kit:Rod(prefix .. "Shin", knee + V(side * 0.07, -0.1, 0.02), foot + V(side * 0.06, 0.2, 0.02), 0.07, bone)
		kit:Part(prefix .. "Shin", V(0.3, 0.12, 0.55), CFrame.new(foot + V(0, 0.06, -0.15)), bone)
		for i = -1, 1 do
			kit:Rod(prefix .. "Shin", foot + V(i * 0.08, 0.05, -0.4), foot + V(i * 0.09, 0.04, -0.62), 0.05, bone)
		end
	end
	local ankle = P.RightFoot + V(0, 0.4, 0)
	kit:Ring("RightShin", CFrame.new(ankle), 0.16, 8, V(0.1, 0.1, 0.14), "Rust")
	kit:Chain("RightShin", ankle + V(0.15, 0, 0), ankle + V(0.4, -0.35, 0.15), 0.18, "Rust")

	-- Tattered cloak and grave mist.
	kit:Cape("Chest", P.Back + V(0, 0.55, 0.12), 1.3, 2.4, 3, ModelKit.Tint("Cloth", { Color = rgb(34, 30, 32) }), "Rust")
	kit:Emit(rig.Hips, "Mist", soul:Lerp(Color3.new(0, 0, 0), 0.55), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 4 })
	kit:Emit(rig.Chest, "Wisps", soul, { Rate = 5, Size = 0.25 })
end
