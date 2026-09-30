--!strict
-- Records how much damage each player deals to a tracked model (the Step 2
-- damage tags).
--
-- Tags live on the model as a folder of NumberValues, one per attacker:
--   Model.DamageTags["<UserId>"].Value = total damage dealt
--   attributes: PlayerName, LastHit (server time)
--
-- Damage gets tagged in two ways:
--   1. ApplyDamage(model, player, amount): the preferred path for your own
--      weapons and skills. Deals the damage and tags it.
--   2. Classic "creator" tags: any weapon that puts an ObjectValue named
--      "creator" (Value = Player) in the Humanoid before damaging it (most
--      toolbox swords, guns and rockets do) is tagged automatically.

local Players = game:GetService("Players")

local TAG_FOLDER_NAME = "DamageTags"

export type Contributor = {
	UserId: number,
	Name: string,
	Player: Player?, -- nil if they left the server
	Damage: number,
	Share: number, -- 0-1 share of all tagged damage
}

type TrackState = {
	Humanoid: Humanoid,
	LastHealth: number,
	Connections: { RBXScriptConnection },
}

local DamageTracker = {}

local tracked: { [Model]: TrackState } = {}

local function getTagFolder(model: Model): Folder
	local folder = model:FindFirstChild(TAG_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = TAG_FOLDER_NAME
	newFolder.Parent = model
	return newFolder
end

-- Adds `amount` to `player`'s damage tag on `model`.
function DamageTracker.Tag(model: Model, player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local folder = getTagFolder(model)
	local key = tostring(player.UserId)
	local tag = folder:FindFirstChild(key) :: NumberValue?
	if not tag then
		local newTag = Instance.new("NumberValue")
		newTag.Name = key
		newTag:SetAttribute("PlayerName", player.Name)
		newTag.Parent = folder
		tag = newTag
	end
	assert(tag)
	tag.Value += amount
	tag:SetAttribute("LastHit", workspace:GetServerTimeNow())
end

-- Deals damage to `model`'s Humanoid on behalf of `player` and tags it.
-- Returns the damage actually dealt (overkill and ForceFields are ignored).
function DamageTracker.ApplyDamage(model: Model, player: Player, amount: number): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return 0
	end
	if model:FindFirstChildOfClass("ForceField") then
		return 0
	end

	local before = humanoid.Health
	local dealt = math.min(amount, before)
	local state = tracked[model]
	if state then
		-- Stops the HealthChanged listener from also crediting a creator tag.
		state.LastHealth = before - dealt
	end
	-- Tag before changing health so the killing blow is counted by the time
	-- Humanoid.Died fires.
	DamageTracker.Tag(model, player, dealt)
	humanoid.Health = before - dealt
	return dealt
end

-- Starts crediting classic "creator" tag damage on `model`.
function DamageTracker.Track(model: Model)
	if tracked[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `DamageTracker.Track: {model:GetFullName()} has no Humanoid`)

	local state: TrackState = {
		Humanoid = humanoid,
		LastHealth = humanoid.Health,
		Connections = {},
	}
	tracked[model] = state
	getTagFolder(model)

	table.insert(
		state.Connections,
		humanoid.HealthChanged:Connect(function()
			-- Read the live value rather than the event argument: with deferred
			-- signals several changes can land before this runs, and
			-- ApplyDamage has already accounted for its own share.
			local newHealth = humanoid.Health
			local delta = state.LastHealth - newHealth
			state.LastHealth = newHealth
			if delta <= 0 then
				return
			end
			local creator = humanoid:FindFirstChild("creator")
			if creator and creator:IsA("ObjectValue") then
				local attacker = creator.Value
				if attacker and attacker:IsA("Player") then
					DamageTracker.Tag(model, attacker, delta)
				end
			end
		end)
	)
	table.insert(
		state.Connections,
		model.Destroying:Connect(function()
			DamageTracker.Untrack(model)
		end)
	)
end

function DamageTracker.Untrack(model: Model)
	local state = tracked[model]
	if not state then
		return
	end
	tracked[model] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
end

-- Everyone who tagged `model`, highest damage first.
function DamageTracker.GetContributors(model: Model): { Contributor }
	local folder = model:FindFirstChild(TAG_FOLDER_NAME)
	if not folder then
		return {}
	end

	local contributors: { Contributor } = {}
	local total = 0
	for _, tag in folder:GetChildren() do
		local userId = tonumber(tag.Name)
		if tag:IsA("NumberValue") and userId and tag.Value > 0 then
			total += tag.Value
			table.insert(contributors, {
				UserId = userId,
				Name = tostring(tag:GetAttribute("PlayerName") or tag.Name),
				Player = Players:GetPlayerByUserId(userId),
				Damage = tag.Value,
				Share = 0,
			})
		end
	end
	for _, contributor in contributors do
		contributor.Share = contributor.Damage / total
	end
	table.sort(contributors, function(a, b)
		return a.Damage > b.Damage
	end)
	return contributors
end

function DamageTracker.ClearTags(model: Model)
	local folder = model:FindFirstChild(TAG_FOLDER_NAME)
	if folder then
		folder:ClearAllChildren()
	end
end

return DamageTracker
