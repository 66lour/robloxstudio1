--!strict
-- Frostbound Banshee: a ghostly bride frozen at the altar. A translucent icy
-- body in a tattered wedding gown and a veil that streams behind her, white
-- hair, a crown of ice spikes, hollow glowing eyes above a screaming jaw, long
-- frozen claws clutching a dead bouquet, and shards of ice circling her.

local Models = script.Parent.Parent
local Armory = require(Models.Armory)
local ModelKit = require(Models.ModelKit)

local rgb = Color3.fromRGB
local V = Vector3.new

return function(kit: ModelKit.Kit, def: any)
	local frost: Color3 = def.Appearance.Aura
	local spirit = ModelKit.Ghost(rgb(170, 210, 240), 0.3)
	local skin = { Material = Enum.Material.Glass, Color = rgb(196, 222, 240), Transparency = 0.15 }
	local gown = { Material = Enum.Material.Fabric, Color = rgb(222, 232, 240), Transparency = 0.25 }
	local veil = { Material = Enum.Material.Fabric, Color = rgb(236, 244, 250), Transparency = 0.45, CastShadow = false }
	local hair = { Material = Enum.Material.Fabric, Color = rgb(230, 236, 244) }
	local hollow = { Material = Enum.Material.SmoothPlastic, Color = rgb(10, 16, 28) }

	local rig = kit:Rig({
		Hover = 2.7,
		Hips = { Size = V(1.0, 0.5, 0.7), Style = spirit },
		Chest = { Size = V(1.4, 1.6, 0.8), Style = skin, Lean = 0.15, Round = true },
		Arms = { Upper = 1.3, Fore = 1.35, Width = 0.24, ShoulderX = 0.9, Style = skin, Round = true },
		Head = { Size = V(0.8, 0.95, 0.85), Style = "Hidden", Neck = 0.25 },
	})
	local P, F = rig.P, rig.F
	local C = F.Chest

	-- Tattered wedding gown in layers, with a laced bodice.
	kit:Robe("Hips", P.Waist + V(0, 0.1, 0), 0.6, 1.7, 2.7, 14, gown)
	kit:Robe("Hips", P.Waist - V(0, 0.15, 0), 0.5, 1.2, 2.4, 10, spirit, 0.8, false)
	kit:Ellipsoid("Chest", V(1.3, 1.2, 0.72), C * CFrame.new(0, -0.1, -0.05), gown)
	for i = 0, 3 do
		local y = 0.3 - i * 0.2
		kit:Rod("Chest", (C * CFrame.new(-0.25, y, -0.42)).Position, (C * CFrame.new(0.25, y - 0.2, -0.42)).Position, 0.03, "Metal")
		kit:Rod("Chest", (C * CFrame.new(0.25, y, -0.42)).Position, (C * CFrame.new(-0.25, y - 0.2, -0.42)).Position, 0.03, "Metal")
	end

	-- Face: gaunt, hollow-eyed, mouth torn open in a scream.
	local H = F.Head
	kit:Ellipsoid("Head", V(0.75, 0.9, 0.8), H * CFrame.new(0, 0.05, 0), skin)
	for _, side in { -1, 1 } do
		kit:Ellipsoid("Head", V(0.24, 0.3, 0.1), H * CFrame.new(side * 0.17, 0.08, -0.38), hollow)
	end
	kit:Eyes("Head", H * CFrame.new(0, 0.08, -0.44), 0.34, V(0.08, 0.06, 0.04), def.Appearance.Eyes)
	kit:Ellipsoid("Head", V(0.3, 0.4, 0.1), H * CFrame.new(0, -0.25, -0.37), hollow)
	kit:Segment("Jaw", "Head", "Jaw", (H * CFrame.new(0, -0.22, 0.05)).Position, V(0.5, 0.15, 0.55), H * CFrame.new(0, -0.48, -0.12) * CFrame.Angles(0.3, 0, 0), skin)
	kit:Hair("Head", H * CFrame.new(0, 0.3, 0.05), 0.38, 14, 2.4, 0.1, hair, 0.8)
	-- Crown of ice spikes on a silver diadem.
	local crown = H * CFrame.new(0, 0.42, 0)
	kit:Ring("Head", crown, 0.36, 10, V(0.18, 0.08, 0.06), "Metal")
	kit:Crown("Head", crown, 0.36, 7, 0.55, 0.1, "Ice", 0.25)
	kit:Ball("Head", 0.12, crown * CFrame.new(0, 0.02, -0.37), ModelKit.Neon(frost))
	-- The veil, streaming from the crown.
	kit:Cape("Head", (H * CFrame.new(0, 0.35, 0.35)).Position, 1.0, 3.6, 3, veil)

	-- Long arms of ice, frozen claws, a dead bouquet and broken spectral chains.
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local hand = P[prefix .. "Hand"]
		kit:Robe(prefix .. "UpperArm", P[prefix .. "Shoulder"] + V(0, 0.05, 0), 0.18, 0.4, 1.0, 6, gown, 1, true)
		Armory.Claws(kit, prefix .. "Forearm", hand, 4, 0.65, 0.3, "Ice")
		kit:Ring(prefix .. "Forearm", CFrame.new(hand + V(0, 0.35, 0)), 0.2, 8, V(0.1, 0.1, 0.12), spirit)
		kit:Chain(prefix .. "Forearm", hand + V(side * 0.2, 0.3, 0.1), hand + V(side * 0.4, -0.7, 0.4), 0.18, spirit)
	end
	local bouquet = P.LeftHand + V(0, -0.35, -0.3)
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		kit:Ball("LeftForearm", 0.2, bouquet + V(math.cos(angle) * 0.14, 0.1 + (i % 2) * 0.08, math.sin(angle) * 0.14), { Material = Enum.Material.SmoothPlastic, Color = rgb(96, 20, 34) })
	end
	kit:Rod("LeftForearm", bouquet, bouquet - V(0, 0.6, -0.1), 0.08, "Ice")

	-- Circling ice shards, falling frost and cold mist.
	local ring = kit:Orbit("Chest", C.Position, 2.2, 4, 0.1, ModelKit.Neon(frost), frost, 0.5)
	for i = 0, 3 do
		local angle = i / 4 * math.pi * 2 + 0.4
		local at = C.Position + V(math.cos(angle) * 2.2, math.sin(angle * 2) * 0.5, math.sin(angle) * 2.2)
		kit:Spike(ring, at - V(0, 0.45, 0), at + V(0, 0.45, 0), 0.3, "Ice", 2)
	end
	kit:Emit(rig.Chest, "Frost", frost, { Rate = 14 })
	kit:Emit(rig.Hips, "Mist", rgb(160, 200, 230), { Offset = V(0, -P.Pelvis.Y + 0.4, 0), Rate = 6 })
	kit:Light(rig.Chest, frost, 12, 1.5)
end
