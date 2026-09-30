--!strict
-- Bloodmoon Werewolf: a hulking wolf-beast. A barrel chest branded with a
-- glowing blood-moon crescent and scarred by claw marks, a bristling mane down
-- its spine, a long snarling muzzle with fangs, huge clawed hands trailing
-- broken shackles, torn trousers and a bushy tail. Red mist curls around it.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local moon: Color3 = def.Appearance.Aura
	local fur = ModelKit.Tint("Fur", { Color = rgb(64, 48, 40) })
	local darkFur = ModelKit.Tint("Fur", { Color = rgb(34, 26, 24) })
	local lightFur = ModelKit.Tint("Fur", { Color = rgb(104, 86, 72) })
	local claw = "Bone"
	local scar = { Material = Enum.Material.SmoothPlastic, Color = rgb(120, 20, 24) }
	local nose = { Material = Enum.Material.SmoothPlastic, Color = rgb(14, 12, 12) }

	local rig = kit:Rig({
		Legs = { Thigh = 1.15, Shin = 1.25, Spacing = 0.55, Width = 0.55, Style = fur, Round = true, Fat = 1.3 },
		Hips = { Size = V(1.5, 0.7, 1.0), Style = fur, Round = true },
		Chest = { Size = V(2.3, 1.9, 1.5), Style = fur, Lean = 0.5, Round = true, Fat = 1.18 },
		Arms = { Upper = 1.35, Fore = 1.45, Width = 0.55, ShoulderX = 1.45, Drop = 0.35, Style = fur, Round = true, Fat = 1.25 },
		Head = { Size = V(1.0, 0.95, 1.1), Style = "Hidden", Neck = 0.1, Tilt = 0.3 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Muscle: pecs, abs, massive shoulders.
	for _, side in { -1, 1 } do
		kit:Ellipsoid("Chest", V(1.05, 0.8, 0.5), C * CFrame.new(side * 0.5, 0.35, -0.7), lightFur)
		kit:Ellipsoid("Chest", V(1.1, 1.0, 1.1), C * CFrame.new(side * 1.2, 0.6, 0), fur)
		for row = 0, 1 do
			kit:Ellipsoid("Chest", V(0.4, 0.3, 0.25), C * CFrame.new(side * 0.22, -0.3 - row * 0.32, -0.72), lightFur)
		end
	end
	-- Blood-moon crescent brand and claw scars.
	for i = 0, 7 do
		local angle = math.pi * 0.25 + i / 7 * math.pi * 1.5
		kit:Part("Chest", V(0.12, 0.12, 0.06), C * CFrame.new(math.cos(angle) * 0.32, 0.35 + math.sin(angle) * 0.32, -0.97), ModelKit.Neon(moon))
	end
	local brand = kit:Part("Chest", V(0.1, 0.1, 0.05), C * CFrame.new(0, 0.35, -0.97), ModelKit.Neon(moon))
	kit:Light(brand, moon, 8, 1.5)
	for i = 0, 2 do
		kit:Rod("Chest", (C * CFrame.new(0.2 + i * 0.18, 0.1, -0.95)).Position, (C * CFrame.new(0.55 + i * 0.18, -0.55, -0.9)).Position, 0.05, scar)
	end

	-- Mane bristling down the neck and spine.
	kit:SpikeRow("Chest", (C * CFrame.new(0, 1.0, 0.5)).Position, (C * CFrame.new(0, -0.8, 0.78)).Position, 8, 0.8, (C.Rotation * CFrame.new(0, 0.8, 1)).Position, 0.3, darkFur)
	for _, side in { -1, 1 } do
		kit:SpikeRow("Chest", (C * CFrame.new(side * 0.5, 0.95, 0.35)).Position, (C * CFrame.new(side * 0.6, -0.2, 0.7)).Position, 5, 0.55, (C.Rotation * CFrame.new(side * 0.6, 0.6, 1)).Position, 0.22, darkFur)
	end

	-- Head: long muzzle, snarling jaw with fangs, tall ears, glowing eyes.
	local H = F.Head
	kit:Ellipsoid("Head", V(1.05, 0.95, 1.05), H * CFrame.new(0, 0.05, 0.1), fur)
	kit:Ellipsoid("Head", V(0.62, 0.5, 1.25), H * CFrame.new(0, -0.12, -0.6), lightFur)
	kit:Ball("Head", 0.22, H * CFrame.new(0, -0.02, -1.2), nose)
	kit:Part("Head", V(0.95, 0.16, 0.35), H * CFrame.new(0, 0.2, -0.42) * CFrame.Angles(-0.3, 0, 0), darkFur)
	for _, side in { -1, 1 } do
		kit:Spike("Head", (H * CFrame.new(side * 0.33, 0.35, 0.15)).Position, (H * CFrame.new(side * 0.5, 1.05, 0.3)).Position, 0.34, fur)
		kit:Spike("Head", (H * CFrame.new(side * 0.2, -0.3, -1.0)).Position, (H * CFrame.new(side * 0.2, -0.58, -1.02)).Position, 0.09, claw, 1)
		kit:Spike("Head", (H * CFrame.new(side * 0.48, 0.0, 0.2)).Position, (H * CFrame.new(side * 0.75, -0.2, 0.5)).Position, 0.25, darkFur)
	end
	kit:Eyes("Head", H * CFrame.new(0, 0.1, -0.5), 0.46, V(0.14, 0.07, 0.05), def.Appearance.Eyes)
	local jawPivot = (H * CFrame.new(0, -0.3, 0.05)).Position
	local jaw = kit:Segment("Jaw", "Head", "Jaw", jawPivot, V(0.5, 0.2, 1.1), H * CFrame.new(0, -0.45, -0.6) * CFrame.Angles(0.15, 0, 0), lightFur)
	for _, side in { -1, 1 } do
		kit:Spike(jaw, (H * CFrame.new(side * 0.18, -0.38, -1.05)).Position, (H * CFrame.new(side * 0.18, -0.12, -1.08)).Position, 0.08, claw, 1)
	end
	kit:Emit(rig.Head, "Smoke", rgb(200, 190, 190), { Rate = 2, Size = 0.35, Offset = V(0, -0.1, -1.2) })

	-- Arms: huge forearms, long claws, broken shackles.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local hand = P[prefix .. "Hand"]
		kit:Ellipsoid(prefix .. "Forearm", V(0.8, 1.0, 0.8), CFrame.new(P[prefix .. "Elbow"] - V(0, 0.45, 0)), fur)
		kit:SpikeRow(prefix .. "Forearm", P[prefix .. "Elbow"] + V(side * 0.3, -0.1, 0.25), P[prefix .. "Elbow"] + V(side * 0.3, -1.0, 0.25), 3, 0.45, V(side, 0.3, 0.6), 0.18, darkFur)
		kit:Ellipsoid(prefix .. "Forearm", V(0.62, 0.45, 0.55), CFrame.new(hand - V(0, 0.12, 0)), lightFur)
		Armory.Claws(kit, prefix .. "Forearm", hand - V(0, 0.28, 0), 4, 0.8, 0.5, claw)
		local wrist = hand + V(0, 0.45, 0)
		kit:Ring(prefix .. "Forearm", CFrame.new(wrist), 0.4, 10, V(0.16, 0.2, 0.2), "Rust")
		kit:Chain(prefix .. "Forearm", wrist + V(side * 0.35, -0.1, 0.2), wrist + V(side * 0.6, -1.2, 0.5), 0.24, "Rust")
	end

	-- Torn trousers, hocked legs with paws, bushy tail.
	kit:Strips("Hips", P.Pelvis + V(-0.75, -0.1, -0.5), P.Pelvis + V(0.75, -0.1, -0.5), 6, 0.4, 1.0, 0.05, ModelKit.Tint("Cloth", { Color = rgb(52, 46, 62) }))
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local foot = P[prefix .. "Foot"]
		kit:Ellipsoid(prefix .. "Shin", V(0.55, 0.3, 1.0), CFrame.new(foot + V(0, 0.15, -0.3)), darkFur)
		Armory.Claws(kit, prefix .. "Shin", foot + V(0, 0.25, -0.72), 3, 0.35, 0.35, claw)
		kit:Ellipsoid(prefix .. "Shin", V(0.5, 0.6, 0.5), CFrame.new(foot + V(0, 0.75, 0.25)), fur)
	end
	kit:Tail("Hips", "Tail", P.Pelvis + V(0, 0.1, 0.55), V(0, 0.2, 1), 2.4, 0.5, 4, darkFur, 1.0, V(1, 0, 0), function(segment, a, b)
		kit:Ellipsoid(segment, V(0.55, 0.55, (b - a).Magnitude * 1.3), ModelKit.Along(a, b), darkFur)
	end)

	kit:Emit(rig.Hips, "Mist", moon:Lerp(Color3.new(0, 0, 0), 0.5), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 5 })
end
