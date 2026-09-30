--!strict
-- Optional: plays uploaded animations (made with the Animation Editor or Moon
-- Animator) on a boss through its Humanoid's Animator. Animations played on the
-- server replicate to every client.
--
-- A boss uses them when either
--   * its BossRoster entry has `Animations = { Idle = "rbxassetid://…",
--     Walk = "rbxassetid://…", Melee = "…", Slam = "…", Attack = "…" }`, or
--   * its custom model (ServerStorage.BossModels) contains a folder named
--     "Animations" with Animation objects named Idle, Walk, Melee, …
-- Action names match BossService.PlayAction (Melee, Slam, Charge, Blink, Drain,
-- Meteor, Nova, Enrage, Spawn, Death); "Attack" is the fallback for any action.
-- The procedural animator then only moves capes, tails, wings and orbits.

local BossRoster = require(game:GetService("ReplicatedStorage").Shared.Config.BossRoster)

type BossDef = BossRoster.BossDef

export type Player = {
	PlayAction: (name: string, duration: number?) -> (),
	Stop: () -> (),
}

local AssetAnimations = {}

local function collectIds(model: Model, def: BossDef): { [string]: string }
	local ids: { [string]: string } = {}
	if def.Animations then
		for name, id in def.Animations do
			if type(id) == "string" and id ~= "" then
				ids[name] = id
			end
		end
	end
	local folder = model:FindFirstChild("Animations")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Animation") and child.AnimationId ~= "" then
				ids[child.Name] = child.AnimationId
			end
		end
	end
	return ids
end

-- Returns a player if the boss has uploaded animations, otherwise nil.
function AssetAnimations.Attach(model: Model, def: BossDef): Player?
	local ids = collectIds(model, def)
	if next(ids) == nil then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid
		animator = newAnimator
	end
	assert(animator)

	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ids do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id
		local ok, trackOrError = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			local track = trackOrError :: AnimationTrack
			track.Priority = if name == "Idle" or name == "Walk" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
			track.Looped = name == "Idle" or name == "Walk"
			tracks[name] = track
		else
			warn(`[Bosses] {def.Name}: could not load animation {name} ({id}): {trackOrError}`)
		end
	end
	model:SetAttribute("UseAssetAnimations", true)

	local idle, walk = tracks.Idle, tracks.Walk
	if idle then
		idle:Play(0.3)
	end
	local walking = false
	local connection = humanoid.Running:Connect(function(speed)
		local moving = speed > 0.5
		if walk and moving ~= walking then
			walking = moving
			if moving then
				walk:Play(0.25)
				if idle then
					idle:Stop(0.25)
				end
			else
				walk:Stop(0.25)
				if idle then
					idle:Play(0.25)
				end
			end
		end
		if walk and moving then
			walk:AdjustSpeed(math.max(0.3, speed / def.WalkSpeed))
		end
	end)

	return {
		PlayAction = function(name: string, duration: number?)
			local track = tracks[name] or tracks.Attack
			if track then
				track:Play(0.1)
				if duration and track.Length > 0 and name ~= "Death" then
					track:AdjustSpeed(math.clamp(track.Length / duration, 0.3, 3))
				end
			end
		end,
		Stop = function()
			connection:Disconnect()
			for _, track in tracks do
				track:Stop(0.2)
			end
		end,
	}
end

return AssetAnimations
