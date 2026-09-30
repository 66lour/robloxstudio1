--!strict
-- Rotting Ghoul: a bloated, hunched corpse-eater. Stitched belly, exposed ribs,
-- a spiny spine, long arms ending in claws, a sagging jaw full of jagged teeth,
-- a gnawed femur for a club, a broken shackle, flies and putrid gas.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local gas: Color3 = def.Appearance.Aura
	local flesh = ModelKit.Tint("Flesh", { Color = rgb(118, 128, 100) })
	local paleFlesh = ModelKit.Tint("Flesh", { Color = rgb(140, 146, 118) })
	local wound = { Material = Enum.Material.Mud, Color = rgb(92, 30, 34) }
	local dark = { Material = Enum.Material.SmoothPlastic, Color = rgb(20, 14, 14) }

	local rig = kit:Rig({
		Legs = { Thigh = 1.0, Shin = 1.05, Spacing = 0.55, Width = 0.5, Style = flesh, Round = true, Fat = 1.25 },
		Hips = { Size = V(1.5, 0.6, 1.0), Style = flesh, Round = true },
		Chest = { Size = V(2.1, 1.7, 1.3), Style = flesh, Lean = 0.6, Round = true, Fat = 1.15 },
		Arms = { Upper = 1.4, Fore = 1.5, Width = 0.42, ShoulderX = 1.3, Drop = 0.35, Style = flesh, Round = true, Fat = 1.2 },
		Head = { Size = V(0.95, 0.9, 1.0), Style = "Hidden", Neck = 0.05, Tilt = 0.25 },
	})
	local P, F = rig.P, rig.F

	-- Bloated, stitched belly and a rib wound on the left flank.
	local belly = kit:Ellipsoid("Hips", V(1.95, 1.5, 1.75), CFrame.new(P.Pelvis + V(0, 0.45, -0.55)), paleFlesh)
	-- Hunched, lumpy back and heavy shoulders.
	kit:Ellipsoid("Chest", V(2.2, 1.5, 1.2), F.Chest * CFrame.new(0, 0.35, 0.3), flesh)
	for _, side in { -1, 1 } do
		kit:Ellipsoid("Chest", V(0.95, 0.8, 0.95), F.Chest * CFrame.new(side * 1.05, 0.55, 0.05), paleFlesh)
	end
	for i = -2, 2 do
		local at = P.Pelvis + V(i * 0.18, 0.62 - math.abs(i) * 0.05, -1.4)
		kit:Rod("Hips", at + V(0, 0.12, 0), at - V(0, 0.12, 0), 0.04, dark)
	end
	kit:Rod("Hips", P.Pelvis + V(-0.45, 0.68, -1.38), P.Pelvis + V(0.45, 0.6, -1.38), 0.04, dark)
	kit:Part("Chest", V(0.1, 0.9, 0.8), F.Chest * CFrame.new(-1.02, -0.1, -0.1), wound)
	for i = 0, 3 do
		kit:Rod("Chest", (F.Chest * CFrame.new(-1.0, 0.25 - i * 0.2, 0.3)).Position, (F.Chest * CFrame.new(-1.1, 0.18 - i * 0.2, -0.45)).Position, 0.07, "OldBone")
	end

	-- Hunched spine studded with bone spurs.
	kit:SpikeRow("Chest", (F.Chest * CFrame.new(0, 0.75, 0.6)).Position, (F.Chest * CFrame.new(0, -0.7, 0.62)).Position, 6, 0.65, (F.Chest.Rotation * CFrame.new(0, 0.4, 1)).Position, 0.2, "OldBone")
	-- Hanging ragged loincloth.
	kit:Strips("Hips", P.Pelvis + V(-0.6, -0.15, -0.62), P.Pelvis + V(0.6, -0.15, -0.62), 5, 0.4, 0.8, 0.05, ModelKit.Tint("Burlap", { Color = rgb(78, 62, 48) }))

	-- Head: heavy brow, sunken eyes, pointed ears, sagging jaw with jagged teeth.
	local H = F.Head
	kit:Ellipsoid("Head", V(1.0, 0.85, 1.05), H * CFrame.new(0, 0.1, 0.05), paleFlesh)
	kit:Part("Head", V(0.95, 0.18, 0.3), H * CFrame.new(0, 0.12, -0.4), flesh)
	for _, side in { -1, 1 } do
		kit:Ball("Head", 0.26, H * CFrame.new(side * 0.22, -0.02, -0.42), dark)
		kit:Spike("Head", (H * CFrame.new(side * 0.48, 0.1, 0.05)).Position, (H * CFrame.new(side * 0.95, 0.35, 0.25)).Position, 0.18, paleFlesh)
	end
	kit:Eyes("Head", H * CFrame.new(0, -0.02, -0.52), 0.44, V(0.1, 0.07, 0.05), def.Appearance.Eyes)
	for i = -2, 2 do
		kit:Spike("Head", (H * CFrame.new(i * 0.13, -0.3, -0.4)).Position, (H * CFrame.new(i * 0.13, -0.5, -0.46)).Position, 0.08, "OldBone", 1)
	end
	local jawPivot = (H * CFrame.new(0, -0.3, 0.1)).Position
	local jaw = kit:Segment("Jaw", "Head", "Jaw", jawPivot, V(0.8, 0.2, 0.75), H * CFrame.new(0, -0.62, -0.15) * CFrame.Angles(0.35, 0, 0), flesh)
	for i = -2, 2 do
		kit:Spike(jaw, (H * CFrame.new(i * 0.14, -0.58, -0.45)).Position, (H * CFrame.new(i * 0.14, -0.35, -0.5)).Position, 0.08, "OldBone", 1)
	end
	kit:Emit(jaw, "Drips", rgb(170, 200, 90), { Rate = 4 })

	-- Long arms: knobby elbows, claws, a gnawed femur and a broken shackle.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Ball(prefix .. "Forearm", 0.5, P[prefix .. "Elbow"], flesh)
		kit:Ellipsoid(prefix .. "UpperArm", V(0.6, 0.7, 0.6), CFrame.new(P[prefix .. "Shoulder"] - V(0, 0.3, 0)), paleFlesh)
		kit:Part(prefix .. "Forearm", V(0.5, 0.35, 0.3), CFrame.new(P[prefix .. "Hand"] - V(0, 0.12, 0)), paleFlesh)
		Armory.Claws(kit, prefix .. "Forearm", P[prefix .. "Hand"] - V(0, 0.28, 0), 4, 0.6, 0.4, "OldBone")
	end
	local femurStart = P.RightHand + V(0, -0.15, 0.25)
	local femurEnd = P.RightHand + V(0, -0.5, -1.4)
	kit:Rod("RightForearm", femurStart, femurEnd, 0.2, "OldBone", true)
	kit:Ball("RightForearm", 0.36, femurEnd, "OldBone")
	kit:Ball("RightForearm", 0.28, femurEnd + V(0.12, 0.12, 0), "OldBone")
	local wrist = P.LeftHand + V(0, 0.35, 0)
	kit:Ring("LeftForearm", CFrame.new(wrist), 0.28, 8, V(0.12, 0.14, 0.16), "Rust")
	kit:Chain("LeftForearm", wrist + V(0, -0.1, 0.28), wrist + V(0.1, -1.4, 0.5), 0.2, "Rust")

	-- Stumpy legs with swollen knees and wide feet.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Ball(prefix .. "Shin", 0.55, P[prefix .. "Knee"], paleFlesh)
		kit:Part(prefix .. "Shin", V(0.6, 0.22, 0.9), CFrame.new(P[prefix .. "Foot"] + V(0, 0.11, -0.2)), flesh)
		for i = -1, 1 do
			kit:Spike(prefix .. "Shin", P[prefix .. "Foot"] + V(i * 0.18, 0.08, -0.62), P[prefix .. "Foot"] + V(i * 0.2, 0.02, -0.85), 0.1, "OldBone", 1)
		end
	end

	-- Flies and putrid gas.
	kit:Emit(rig.Head, "Flies", rgb(20, 20, 16), { Rate = 14 })
	kit:Emit(belly, "Smoke", gas, { Rate = 5, Size = 1.0 })
	kit:Emit(rig.Hips, "Mist", gas:Lerp(Color3.new(0, 0, 0), 0.4), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 3 })
end
