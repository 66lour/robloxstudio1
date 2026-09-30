--!strict
-- Bog Hag: a bent crone in rotting, moss-covered robes. Deep hood, hooked nose,
-- wild grey hair, long nails, a gnarled staff crowned with a skull and a green
-- witch-flame, charms and potion bottles on her belt, swamp mist and dripping
-- water.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local witchfire: Color3 = def.Appearance.Aura
	local robe = ModelKit.Tint("Cloth", { Color = rgb(44, 58, 40) })
	local robeDark = ModelKit.Tint("Cloth", { Color = rgb(30, 38, 28) })
	local skin = ModelKit.Tint("Flesh", { Color = rgb(116, 138, 98) })
	local hair = ModelKit.Tint("Cloth", { Color = rgb(160, 164, 150), Material = Enum.Material.Fabric })
	local dark = { Material = Enum.Material.SmoothPlastic, Color = rgb(16, 14, 12) }

	local rig = kit:Rig({
		Legs = { Thigh = 1.1, Shin = 1.1, Spacing = 0.35, Width = 0.3, Style = robeDark },
		Hips = { Size = V(1.4, 0.5, 0.9), Style = robe },
		Chest = { Size = V(1.6, 1.5, 0.95), Style = robe, Lean = 0.7, Round = true, Fat = 1.2 },
		Arms = { Upper = 1.2, Fore = 1.3, Width = 0.3, ShoulderX = 0.95, Style = robe, ForeStyle = skin },
		Head = { Size = V(0.85, 0.95, 0.9), Style = "Hidden", Neck = 0.05, Tilt = 0.45 },
	})
	local P, F = rig.P, rig.F

	-- Flared robe down to the ground, a hump of moss on her back.
	kit:Robe("Hips", P.Waist, 0.72, 1.25, 2.15, 10, robe)
	kit:Robe("Chest", (F.Chest * CFrame.new(0, 0.55, 0)).Position, 0.9, 1.05, 1.3, 8, robeDark, 0.8, false)
	for i = 0, 4 do
		local at = F.Chest * CFrame.new(kit:Rand(-0.5, 0.5), kit:Rand(-0.3, 0.6), 0.5)
		kit:Ellipsoid("Chest", V(kit:Rand(0.4, 0.7), 0.25, kit:Rand(0.4, 0.6)), at * CFrame.Angles(math.pi / 2 - 0.3, 0, 0), "Moss")
	end
	kit:Strips("Chest", (F.Chest * CFrame.new(-0.8, -0.3, 0.5)).Position, (F.Chest * CFrame.new(0.8, -0.3, 0.5)).Position, 6, 0.3, 0.9, 0.04, "Moss", 0.2)

	-- Deep hood, hooked nose, warts, a crooked grin and wild hair.
	local H = F.Head
	kit:Ellipsoid("Head", V(1.2, 1.25, 1.3), H * CFrame.new(0, 0.15, 0.2), robeDark)
	kit:Ellipsoid("Head", V(0.75, 0.85, 0.7), H * CFrame.new(0, -0.05, -0.12), skin)
	kit:Spike("Head", (H * CFrame.new(0, 0.02, -0.45)).Position, (H * CFrame.new(0, -0.3, -0.95)).Position, 0.18, skin, 3)
	for _, offset in { V(0.2, -0.2, -0.45), V(-0.15, 0.2, -0.45), V(0.05, -0.12, -0.72) } do
		kit:Ball("Head", 0.07, H * CFrame.new(offset), skin)
	end
	kit:Eyes("Head", H * CFrame.new(0, 0.08, -0.47), 0.36, V(0.11, 0.07, 0.05), def.Appearance.Eyes)
	kit:Part("Head", V(0.42, 0.05, 0.05), H * CFrame.new(0, -0.3, -0.45) * CFrame.Angles(0, 0, 0.12), dark)
	for i = -1, 1, 2 do
		kit:Spike("Head", (H * CFrame.new(i * 0.1, -0.29, -0.46)).Position, (H * CFrame.new(i * 0.1, -0.42, -0.48)).Position, 0.05, "OldBone", 1)
	end
	kit:Hair("Head", H * CFrame.new(0, 0.05, 0), 0.5, 11, 1.4, 0.12, hair, 0.2)

	-- Bony arms with long nails; a gnarled staff with a skull and witch-flame.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		kit:Robe(prefix .. "UpperArm", P[prefix .. "Shoulder"] + V(0, 0.1, 0), 0.28, 0.42, 1.25, 6, robe, 1, true)
		kit:Ball(prefix .. "Forearm", 0.3, P[prefix .. "Elbow"], skin)
		Armory.Claws(kit, prefix .. "Forearm", P[prefix .. "Hand"] - V(0, 0.08, 0), 4, 0.42, 0.28, "OldBone")
	end
	Armory.Staff(kit, "RightForearm", P.RightHand, {
		Length = 4.4,
		Haft = "DeadWood",
		Orb = ModelKit.Neon(witchfire, 0.25),
		OrbSize = 0.4,
		Glow = witchfire,
		Skull = true,
		Prongs = 3,
	})

	-- Belt of charms: bones, bottles of glowing brew, a pouch.
	kit:Part("Hips", V(1.5, 0.16, 1.0), CFrame.new(P.Waist - V(0, 0.05, 0)), "Leather")
	local charms = { V(-0.6, -0.2, -0.45), V(-0.25, -0.25, -0.52), V(0.3, -0.22, -0.5), V(0.62, -0.2, -0.4) }
	for index, offset in charms do
		local hook = P.Waist + offset
		if index % 2 == 0 then
			kit:Part("Hips", V(0.16, 0.26, 0.16), CFrame.new(hook - V(0, 0.18, 0)), { Material = Enum.Material.Glass, Color = rgb(60, 90, 60), Transparency = 0.3 })
			kit:Part("Hips", V(0.1, 0.14, 0.1), CFrame.new(hook - V(0, 0.2, 0)), ModelKit.Neon(if index == 2 then witchfire else rgb(170, 60, 200)))
		else
			kit:Rod("Hips", hook, hook - V(0.05, 0.4, 0), 0.06, "OldBone")
			kit:Ball("Hips", 0.1, hook - V(0.05, 0.42, 0), "OldBone")
		end
	end
	kit:Ellipsoid("Hips", V(0.35, 0.4, 0.3), CFrame.new(P.Waist + V(0.72, -0.35, 0.1)), "Leather")

	-- Swamp mist, dripping hem, a few flies.
	kit:Emit(rig.Hips, "Mist", witchfire:Lerp(Color3.new(0, 0, 0), 0.5), { Offset = V(0, -P.Pelvis.Y + 0.3, 0), Rate = 5 })
	kit:Emit(rig.Hips, "Drips", rgb(120, 170, 110), { Offset = V(0, -1.6, -0.6), Rate = 3 })
	kit:Emit(rig.Head, "Flies", rgb(20, 24, 16), { Rate = 6 })
end
