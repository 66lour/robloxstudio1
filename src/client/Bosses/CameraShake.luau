--!strict
-- Small camera shake for boss footfalls and impacts, applied through the local
-- Humanoid's CameraOffset (added on top of whatever else uses it).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraShake = {}

local intensity = 0
local applied = Vector3.zero
local started = false

function CameraShake.Impulse(amount: number)
	intensity = math.min(1.5, intensity + amount)
end

-- Shake scaled by how close the camera's subject is to `position`.
function CameraShake.At(position: Vector3, strength: number, radius: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local distance = (root.Position - position).Magnitude
	if distance < radius then
		CameraShake.Impulse(strength * (1 - distance / radius))
	end
end

function CameraShake.Start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			applied = Vector3.zero
			return
		end
		local base = humanoid.CameraOffset - applied
		local offset = Vector3.zero
		if intensity > 0.002 then
			local t = os.clock() * 40
			offset = Vector3.new(math.noise(t, 0.3), math.noise(t, 7.1), math.noise(t, 13.7)) * intensity
			intensity *= math.exp(-dt * 7)
		else
			intensity = 0
		end
		humanoid.CameraOffset = base + offset
		applied = offset
	end)
end

return CameraShake
