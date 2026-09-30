--!strict
-- Studio-only testing helpers. Not started in live servers.
--
--   * Gives every player a "Test Soulreaver" sword. Its hits go through
--     DamageTracker.ApplyDamage, so they are tagged like real combat. Each hit
--     deals 2% of the boss's max health (at least 150) so even Mythics die fast.
--   * Chat "!boss <id>" (e.g. "!boss pale_king") to spawn a specific boss, or
--     "!boss" for a random roll.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local BossBuilder = require(script.Parent.Parent.Bosses.BossBuilder)
local BossService = require(script.Parent.Parent.Bosses.BossService)
local DamageTracker = require(script.Parent.Parent.Services.DamageTracker)

local SWING_COOLDOWN = 0.35
local BASE_REACH = 9

local DevTools = {}

local function makeSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Test Soulreaver"
	tool.ToolTip = "Studio test weapon"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -1.6, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 4, 0.3)
	handle.Color = Color3.fromRGB(170, 60, 255)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local lastSwing = 0
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwing < SWING_COOLDOWN then
			return
		end
		lastSwing = now

		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not player or not root then
			return
		end

		for _, instance in CollectionService:GetTagged(BossBuilder.Tag) do
			local boss = instance :: Model
			local bossRoot = boss.PrimaryPart
			local humanoid = boss:FindFirstChildOfClass("Humanoid")
			if bossRoot and humanoid and humanoid.Health > 0 then
				local reach = BASE_REACH + bossRoot.Size.X
				if (bossRoot.Position - root.Position).Magnitude <= reach then
					DamageTracker.ApplyDamage(boss, player, math.max(150, humanoid.MaxHealth * 0.02))
				end
			end
		end
	end)

	return tool
end

local function giveSword(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack and not backpack:FindFirstChild("Test Soulreaver") then
		makeSword().Parent = backpack
	end
end

local function onChatted(message: string)
	local command, match = string.match(message, "^!(%w+)%s*(%S*)")
	if command ~= "boss" then
		return
	end
	local argument = match or ""
	if argument ~= "" and not BossRoster.Get(argument) then
		local ids = {}
		for _, def in BossRoster.List do
			table.insert(ids, def.Id)
		end
		warn(`[DevTools] Unknown boss "{argument}". Ids: {table.concat(ids, ", ")}`)
		return
	end
	BossService.Spawn(if argument ~= "" then argument else nil)
end

function DevTools.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			giveSword(player)
		end)
		if player.Character then
			task.spawn(giveSword, player)
		end
		player.Chatted:Connect(onChatted)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	print("[DevTools] Studio test sword enabled. Chat '!boss <id>' to spawn a boss.")
end

return DevTools
