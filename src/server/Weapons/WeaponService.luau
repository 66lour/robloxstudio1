--!strict
-- Server-side melee weapons. Damage per hit comes from WeaponCatalog, from the
-- 5-damage starter weapon up to the 1000-damage Reaper's Mythic Blade.
--
-- Any Tool whose name (or "WeaponId" attribute) matches a WeaponCatalog entry
-- is taken over when it reaches a player's Backpack or character, wherever it
-- came from (StarterPack, a shop, your inventory system…). So your existing
-- weapon models keep their looks: put them in ServerStorage.Weapons (or
-- StarterPack) with the catalog names and delete any old damage scripts
-- inside them, otherwise they deal damage twice.
--
-- A swing plays the default slash animation, then hits the boss in reach
-- through BossService.DamageBoss (which tags the damage for loot and refuses
-- guests). The attacker sees a damage number.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponCatalog = require(ReplicatedStorage.Shared.Config.WeaponCatalog)
local BossBuilder = require(script.Parent.Parent.Bosses.BossBuilder)
local BossEffects = require(script.Parent.Parent.Bosses.BossEffects)
local BossService = require(script.Parent.Parent.Bosses.BossService)
local WeaponModels = require(script.Parent.WeaponModels)

type WeaponDef = WeaponCatalog.WeaponDef

local SETTINGS = {
	-- Give every player the catalog's Starter weapons each time they spawn.
	GiveStarterWeapons = true,
	-- Your own weapon models (Tools named like the catalog entries).
	CustomFolderName = "Weapons",
	-- Seconds between the swing starting and the hit landing.
	HitDelay = 0.12,
}

local WeaponService = {}

local wired: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastSwing: { [Tool]: number } = setmetatable({}, { __mode = "k" }) :: any
local damageRemote = Remotes.Get("DamageDealt")

local function definitionFor(tool: Tool): WeaponDef?
	local id = tool:GetAttribute("WeaponId")
	if type(id) == "string" then
		local byId = WeaponCatalog.Get(id)
		if byId then
			return byId
		end
	end
	return WeaponCatalog.ByName[tool.Name]
end

-- Rough radius of a boss's body around its root, cached on the model.
local function hitRadius(boss: Model): number
	local cached = boss:GetAttribute("HitRadius")
	if type(cached) == "number" then
		return cached
	end
	local size = boss:GetExtentsSize()
	local radius = math.max(2, math.min(size.X, size.Z) * 0.4)
	boss:SetAttribute("HitRadius", radius)
	return radius
end

-- The closest boss this player can reach with `def`, and where the hit lands.
local function bossInReach(player: Player, def: WeaponDef): (Model?, Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local best: Model? = nil
	local bestPoint: Vector3? = nil
	local bestGap = math.huge
	for _, instance in CollectionService:GetTagged(BossBuilder.Tag) do
		local boss = instance :: Model
		local bossRoot = boss.PrimaryPart
		local humanoid = boss:FindFirstChildOfClass("Humanoid")
		if bossRoot and humanoid and humanoid.Health > 0 then
			local offset = bossRoot.Position - root.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local radius = hitRadius(boss)
			local gap = flatOffset.Magnitude - radius
			local height = boss:GetExtentsSize().Y
			local withinHeight = root.Position.Y > bossRoot.Position.Y - height and root.Position.Y < bossRoot.Position.Y + height
			if gap <= def.Range and gap < bestGap and withinHeight then
				local direction = if flatOffset.Magnitude > 0.01 then flatOffset.Unit else root.CFrame.LookVector
				-- Swinging at the boss: it must be roughly in front unless we're touching it.
				if gap < 2 or root.CFrame.LookVector:Dot(direction) > 0.1 then
					best = boss
					bestGap = gap
					bestPoint = Vector3.new(bossRoot.Position.X, root.Position.Y + 1, bossRoot.Position.Z) - direction * radius
				end
			end
		end
	end
	return best, bestPoint
end

local function swing(tool: Tool, def: WeaponDef)
	local now = os.clock()
	if lastSwing[tool] and now - lastSwing[tool] < def.Cooldown then
		return
	end
	lastSwing[tool] = now
	local character = tool.Parent
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	if not player then
		return
	end

	-- The default Animate script plays its slash animation for this value.
	local slash = Instance.new("StringValue")
	slash.Name = "toolanim"
	slash.Value = "Slash"
	slash.Parent = tool
	Debris:AddItem(slash, 1)
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("Trail") and descendant.Name == "SwingTrail" then
			descendant.Enabled = true
			task.delay(0.35, function()
				descendant.Enabled = false
			end)
		end
	end

	task.wait(SETTINGS.HitDelay)
	local boss, point = bossInReach(player, def)
	if not boss or not point then
		return
	end
	local dealt = BossService.DamageBoss(boss, player, def.Damage)
	if dealt > 0 then
		local color = def.Glow or Rarities.Get(def.Rarity).Color
		BossEffects.Shockwave(point, 1.2 + math.log10(def.Damage) * 0.5, color)
		damageRemote:FireClient(player, { Position = point, Amount = math.floor(dealt + 0.5), Rarity = def.Rarity })
	end
end

local function wire(instance: Instance)
	if not instance:IsA("Tool") or wired[instance] then
		return
	end
	local tool = instance
	local def = definitionFor(tool)
	if not def then
		return
	end
	wired[tool] = true
	tool:SetAttribute("WeaponId", def.Id)
	tool:SetAttribute("Damage", def.Damage)
	tool.ToolTip = `{def.Name} · {def.Damage} damage`
	tool.Activated:Connect(function()
		swing(tool, def)
	end)
end

local function owns(player: Player, name: string): boolean
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character, player:FindFirstChild("StarterGear") }
	for _, container in containers do
		if container and container:FindFirstChild(name) then
			return true
		end
	end
	return false
end

-- Creates the Tool for a weapon: your model from ServerStorage.Weapons if it
-- exists, otherwise the built-in one.
function WeaponService.CreateTool(idOrName: string): Tool
	local def = assert(WeaponCatalog.Get(idOrName), `Unknown weapon "{idOrName}"`)
	local folder = ServerStorage:FindFirstChild(SETTINGS.CustomFolderName)
	local custom = folder and folder:FindFirstChild(def.Name)
	local tool = if custom and custom:IsA("Tool") then custom:Clone() else WeaponModels.Build(def)
	tool:SetAttribute("WeaponId", def.Id)
	return tool
end

-- Puts a weapon in the player's Backpack. With `permanent`, a copy also goes
-- into StarterGear so it comes back after respawning.
function WeaponService.Give(player: Player, idOrName: string, permanent: boolean?): Tool?
	local def = WeaponCatalog.Get(idOrName)
	if not def then
		warn(`[Weapons] Unknown weapon "{idOrName}"`)
		return nil
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end
	local tool = WeaponService.CreateTool(def.Id)
	tool.Parent = backpack
	if permanent then
		local gear = player:FindFirstChild("StarterGear")
		if gear and not gear:FindFirstChild(def.Name) then
			WeaponService.CreateTool(def.Id).Parent = gear
		end
	end
	return tool
end

local function onCharacter(player: Player, character: Model)
	character.ChildAdded:Connect(wire)
	for _, child in character:GetChildren() do
		wire(child)
	end
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	backpack.ChildAdded:Connect(wire)
	for _, child in backpack:GetChildren() do
		wire(child)
	end
	if SETTINGS.GiveStarterWeapons then
		-- Give StarterPack/StarterGear a moment to hand out their copies first.
		task.wait(0.5)
		for _, def in WeaponCatalog.List do
			if def.Starter and player.Parent and not owns(player, def.Name) then
				WeaponService.Give(player, def.Id)
			end
		end
	end
end

function WeaponService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return WeaponService
