--!strict
-- Runs the world boss: building and placing it, its AI, damage from players,
-- and its death (loot goes to LootService). Only ONE boss exists at a time;
-- BossSpawnCycle decides when and where the next one appears.
--
-- Targeting (plot-only aggro): the boss hunts the nearest player who is
-- assigned to a tycoon plot and not standing inside their own tycoon
-- (PlotService). Guests are ignored completely and can't be hurt. Once it has
-- a target it pursues relentlessly (walking around obstacles) until the target
-- becomes invalid; recent attackers get priority. With nobody to hunt it walks
-- back to the portal and regenerates.
--
-- Other scripts damage the boss with BossService.DamageBoss(model, player, amount).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DamageTracker = require(script.Parent.Parent.Services.DamageTracker)
local LootService = require(script.Parent.Parent.Services.LootService)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local AssetAnimations = require(script.Parent.AssetAnimations)
local BossAbilities = require(script.Parent.BossAbilities)
local BossBuilder = require(script.Parent.BossBuilder)
local BossEffects = require(script.Parent.BossEffects)
local BossNavigator = require(script.Parent.BossNavigator)
local BossSettings = require(script.Parent.BossSettings)

type BossDef = BossRoster.BossDef
type BossStats = BossRoster.BossStats

export type ActiveBoss = {
	Def: BossDef,
	Stats: BossStats,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Home: CFrame,
	Alive: boolean,
	DamageMult: number,
	SpeedMult: number,
	CooldownMult: number,
	Abilities: { { [string]: any } },
	ReadyAt: { [any]: number },
	NextAttack: number,
	LastCombat: number,
	TriggeredPassives: { [any]: boolean },
	Target: Player?,
	RecentAttackers: { [Player]: number },
	Navigator: BossNavigator.Navigator,
	ActionSeq: number,
	Assets: AssetAnimations.Player?,
	EmergedAt: number,
}

local ENRAGE_TINT = Color3.fromRGB(255, 40, 30)
local NOTICE_COOLDOWN = 4

local BossService = {}

local spawnedEvent = Instance.new("BindableEvent")
local removedEvent = Instance.new("BindableEvent")
-- Fires (model: Model, def) when a boss appears.
BossService.Spawned = spawnedEvent.Event
-- Fires (def, reason) when the boss is gone: "Defeated", "Despawned", "Replaced" or "Lost".
BossService.Removed = removedEvent.Event

local rng = Random.new()
local current: ActiveBoss? = nil
local bossAnnouncement = Remotes.Get("BossAnnouncement")
local noticeRemote = Remotes.Get("Notice")
local lastNotice: { [Player]: number } = {}

local bossFolder = Instance.new("Folder")
bossFolder.Name = "Bosses"
bossFolder.Parent = Workspace

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function walkSpeed(boss: ActiveBoss): number
	return math.min(boss.Def.WalkSpeed * boss.SpeedMult, BossRoster.MAX_WALK_SPEED)
end

local function sendNotice(player: Player, text: string)
	local now = os.clock()
	if lastNotice[player] and now - lastNotice[player] < NOTICE_COOLDOWN then
		return
	end
	lastNotice[player] = now
	noticeRemote:FireClient(player, { Text = text })
end

-- Animations --------------------------------------------------------------------

-- Tells every client to play `name` (see client ActionPoses); also plays an
-- uploaded animation if the boss has one.
function BossService.PlayAction(boss: ActiveBoss, name: string, windup: number, duration: number?)
	local model = boss.Model
	boss.ActionSeq += 1
	model:SetAttribute("Action", name)
	model:SetAttribute("ActionWindup", windup)
	model:SetAttribute("ActionDuration", duration or windup)
	model:SetAttribute("ActionStart", Workspace:GetServerTimeNow())
	model:SetAttribute("ActionSeq", boss.ActionSeq)
	if boss.Assets then
		boss.Assets.PlayAction(name, duration or windup)
	end
end

-- Passives ----------------------------------------------------------------------

local function tintAura(boss: ActiveBoss, color: Color3)
	for _, descendant in boss.Model:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Color = descendant.Color:Lerp(color, 0.6)
		end
	end
end

local function checkPassives(boss: ActiveBoss)
	local humanoid = boss.Humanoid
	for _, passive in boss.Def.Passives do
		if passive.Kind == "Enrage" and not boss.TriggeredPassives[passive] and humanoid.Health > 0 then
			if humanoid.Health <= humanoid.MaxHealth * passive.Threshold then
				boss.TriggeredPassives[passive] = true
				boss.DamageMult *= passive.DamageMult
				boss.SpeedMult *= passive.SpeedMult
				boss.CooldownMult *= passive.CooldownMult
				humanoid.WalkSpeed = walkSpeed(boss)
				tintAura(boss, ENRAGE_TINT)
				BossEffects.Shockwave(boss.Root.Position, 10 * boss.Stats.Scale, ENRAGE_TINT)
				boss.Model:SetAttribute("Enraged", true)
				BossService.PlayAction(boss, "Enrage", 0, 1.5)
			end
		end
	end
end

local function resetPassives(boss: ActiveBoss)
	if next(boss.TriggeredPassives) == nil then
		return
	end
	boss.TriggeredPassives = {}
	boss.DamageMult, boss.SpeedMult, boss.CooldownMult = 1, 1, 1
	boss.Humanoid.WalkSpeed = walkSpeed(boss)
	boss.Model:SetAttribute("Enraged", nil)
end

-- Targeting ---------------------------------------------------------------------

-- The best player to hunt: closest valid target, preferring recent attackers
-- and (a little) the current target so the boss doesn't flip-flop.
local function selectTarget(boss: ActiveBoss): (Player?, BasePart?, number)
	local now = os.clock()
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestScore, bestDistance = math.huge, math.huge
	for _, player in Players:GetPlayers() do
		if PlotService.CanBeTargeted(player) then
			local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
			local distance = (root.Position - boss.Root.Position).Magnitude
			if distance <= BossSettings.HuntRange then
				local score = distance
				local hitAt = boss.RecentAttackers[player]
				if hitAt and now - hitAt < 8 then
					score -= BossSettings.RecentAttackerBonus
				end
				if player == boss.Target then
					score *= 1 - BossSettings.Stickiness
				end
				if score < bestScore then
					bestPlayer, bestRoot, bestScore, bestDistance = player, root, score, distance
				end
			end
		end
	end
	return bestPlayer, bestRoot, bestDistance
end

local function setTarget(boss: ActiveBoss, player: Player?)
	if boss.Target ~= player then
		boss.Target = player
		boss.Model:SetAttribute("TargetUserId", if player then player.UserId else nil)
	end
end

-- AI ----------------------------------------------------------------------------

local function makeContext(boss: ActiveBoss, targetRoot: BasePart): BossAbilities.Context
	return {
		Model = boss.Model,
		Root = boss.Root,
		Humanoid = boss.Humanoid,
		Def = boss.Def,
		Stats = boss.Stats,
		Color = boss.Def.Appearance.Aura,
		TargetRoot = targetRoot,
		GetDamage = function()
			return boss.Stats.Damage * boss.DamageMult
		end,
		GetWalkSpeed = function()
			return walkSpeed(boss)
		end,
		IsAlive = function()
			return boss.Alive and boss.Model.Parent ~= nil
		end,
		PlayAction = function(name: string, windup: number, duration: number?)
			BossService.PlayAction(boss, name, windup, duration)
		end,
	}
end

local function pickAbility(boss: ActiveBoss, distance: number): { [string]: any }?
	local now = os.clock()
	local ready = {}
	for _, spec in boss.Abilities do
		if now >= boss.ReadyAt[spec] and BossAbilities.CanUse(spec, distance) then
			table.insert(ready, spec)
		end
	end
	if #ready == 0 then
		return nil
	end
	return ready[rng:NextInteger(1, #ready)]
end

local function face(boss: ActiveBoss, position: Vector3)
	local from = boss.Root.Position
	local to = Vector3.new(position.X, from.Y, position.Z)
	if flat(to - from).Magnitude > 0.1 then
		boss.Root.CFrame = CFrame.lookAt(from, to)
	end
end

local function melee(boss: ActiveBoss, player: Player, targetRoot: BasePart)
	boss.NextAttack = os.clock() + boss.Def.AttackCooldown * boss.CooldownMult
	boss.Humanoid:MoveTo(boss.Root.Position)
	face(boss, targetRoot.Position)
	BossService.PlayAction(boss, "Melee", BossSettings.MeleeWindup)
	task.wait(BossSettings.MeleeWindup)
	if not boss.Alive or not targetRoot.Parent or not PlotService.CanBeTargeted(player) then
		return
	end
	local reach = BossSettings.MeleeReach + 2 * boss.Stats.Scale
	if (targetRoot.Position - boss.Root.Position).Magnitude <= reach * 1.25 then
		local humanoid = (targetRoot.Parent :: Instance):FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(boss.Stats.Damage * boss.DamageMult)
			BossEffects.Shockwave(targetRoot.Position, 2.5, boss.Def.Appearance.Aura)
		end
	end
end

local function regenerate(boss: ActiveBoss, dt: number)
	local humanoid = boss.Humanoid
	if humanoid.Health >= humanoid.MaxHealth then
		return
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * BossSettings.IdleRegenRate * dt)
	if humanoid.Health >= humanoid.MaxHealth then
		DamageTracker.ClearTags(boss.Model)
		resetPassives(boss)
	end
end

local function think(boss: ActiveBoss)
	local now = os.clock()
	if now < boss.EmergedAt then
		return
	end
	local humanoid = boss.Humanoid
	local home = boss.Home.Position

	if flat(home - boss.Root.Position).Magnitude > BossSettings.MaxDistanceFromPortal then
		boss.Model:PivotTo(boss.Home)
		setTarget(boss, nil)
		return
	end

	local player, targetRoot, distance = selectTarget(boss)
	setTarget(boss, player)
	if not player or not targetRoot then
		if flat(home - boss.Root.Position).Magnitude > 8 then
			boss.Navigator:MoveTo(home)
		else
			boss.Navigator:Stop()
		end
		if now - boss.LastCombat > BossSettings.IdleRegenDelay then
			regenerate(boss, BossSettings.ThinkInterval)
		end
		return
	end

	local spec = pickAbility(boss, distance)
	if spec then
		boss.LastCombat = now
		boss.ReadyAt[spec] = now + spec.Cooldown * boss.CooldownMult
		BossAbilities.Run(makeContext(boss, targetRoot), spec)
		boss.NextAttack = math.max(boss.NextAttack, os.clock() + 0.6)
		return
	end

	local reach = BossSettings.MeleeReach + 2 * boss.Stats.Scale
	if distance <= reach then
		boss.LastCombat = now
		if now >= boss.NextAttack then
			melee(boss, player, targetRoot)
		else
			humanoid:MoveTo(boss.Root.Position)
			face(boss, targetRoot.Position)
		end
	else
		boss.Navigator:MoveTo(targetRoot.Position)
	end
end

local function runAI(boss: ActiveBoss)
	while boss.Alive and boss.Model.Parent do
		local ok, err = pcall(think :: any, boss)
		if not ok then
			warn(`[Bosses] AI error on {boss.Def.Name}: {err}`)
		end
		task.wait(BossSettings.ThinkInterval)
	end
end

-- Lifecycle -----------------------------------------------------------------------

local function release(boss: ActiveBoss, reason: string)
	if current ~= boss then
		return
	end
	current = nil
	if boss.Assets and reason ~= "Defeated" then
		boss.Assets.Stop()
	end
	removedEvent:Fire(boss.Def, reason)
end

local function onDied(boss: ActiveBoss)
	if not boss.Alive then
		return
	end
	boss.Alive = false
	local position = boss.Root.Position
	setTarget(boss, nil)
	BossService.PlayAction(boss, "Death", 0, 600)

	-- Let any deferred HealthChanged handlers credit the final hits.
	task.wait()

	local contributors = DamageTracker.GetContributors(boss.Model)
	DamageTracker.Untrack(boss.Model)
	BossEffects.Dissolve(boss.Model, boss.Def.Appearance.Aura, BossSettings.CorpseDuration)

	if #contributors > 0 then
		LootService.HandleBossDefeat(boss.Def, contributors, position)
	else
		print(`[Bosses] {boss.Def.Name} died with no player damage; no loot`)
	end

	release(boss, "Defeated")
	task.delay(BossSettings.CorpseDuration + 0.5, function()
		boss.Model:Destroy()
	end)
end

-- Height of the root part above the ground when standing.
local function standingHeight(model: Model, humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	return root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
end

-- Public API ------------------------------------------------------------------------

-- Whether `player` may hurt bosses (guests can't unless GuestsCanDamageBosses).
function BossService.CanPlayerDamage(player: Player): boolean
	return BossSettings.GuestsCanDamageBosses or PlotService.IsAssigned(player)
end

-- Deals damage to the active boss on behalf of `player` (tags it for loot).
-- Returns the damage actually dealt.
function BossService.DamageBoss(model: Model, player: Player, amount: number): number
	local boss = current
	if not boss or boss.Model ~= model or not boss.Alive then
		return 0
	end
	if not BossService.CanPlayerDamage(player) then
		sendNotice(player, "Claim a tycoon plot to fight the boss!")
		return 0
	end
	local dealt = DamageTracker.ApplyDamage(model, player, amount)
	if dealt > 0 then
		local now = os.clock()
		boss.RecentAttackers[player] = now
		boss.LastCombat = now
	end
	return dealt
end

function BossService.GetActive(): ActiveBoss?
	return current
end

-- Spawns a boss standing at `spawnCFrame` (on the ground, facing its look
-- direction). Pass a boss id to force one; otherwise it is rolled by spawn
-- weight. Refuses (returns nil) while another boss is alive: one boss per map.
function BossService.Spawn(bossId: string?, spawnCFrame: CFrame): Model?
	if current then
		warn(`[Bosses] {current.Def.Name} is still alive; only one boss can exist at a time`)
		return nil
	end
	local def: BossDef
	if bossId then
		def = assert(BossRoster.Get(bossId), `Unknown boss id "{bossId}"`)
	else
		def = BossRoster.RollBoss(rng)
	end
	local stats = BossRoster.GetStats(def)
	local model = BossBuilder.Build(def, stats)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart

	model:PivotTo(spawnCFrame * CFrame.new(0, standingHeight(model, humanoid, root), 0))
	model.Parent = bossFolder
	root:SetNetworkOwner(nil)

	local now = os.clock()
	local boss: ActiveBoss = {
		Def = def,
		Stats = stats,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Home = root.CFrame,
		Alive = true,
		DamageMult = 1,
		SpeedMult = 1,
		CooldownMult = 1,
		Abilities = {},
		ReadyAt = {},
		NextAttack = now,
		LastCombat = now,
		TriggeredPassives = {},
		Target = nil,
		RecentAttackers = {},
		Navigator = BossNavigator.new(model, humanoid, root, stats.Scale),
		ActionSeq = 0,
		Assets = nil,
		EmergedAt = now + BossSettings.EmergeDuration,
	}
	for _, rawSpec in def.Abilities do
		local spec = BossAbilities.Resolve(rawSpec)
		table.insert(boss.Abilities, spec)
		-- Stagger first casts so a boss doesn't open with every ability at once.
		boss.ReadyAt[spec] = now + BossSettings.EmergeDuration + rng:NextNumber(2, math.max(3, spec.Cooldown * 0.6))
	end
	humanoid.WalkSpeed = walkSpeed(boss)
	current = boss
	boss.Assets = AssetAnimations.Attach(model, def)

	DamageTracker.Track(model, BossService.CanPlayerDamage)
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function()
		local health = humanoid.Health
		if health < lastHealth then
			boss.LastCombat = os.clock()
		end
		lastHealth = health
		BossBuilder.UpdateHealthBar(model, health, humanoid.MaxHealth)
		checkPassives(boss)
	end)
	humanoid.Died:Connect(function()
		onDied(boss)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and boss.Alive then
			-- Removed without dying (e.g. fell out of the world).
			boss.Alive = false
			release(boss, "Lost")
		end
	end)

	BossService.PlayAction(boss, "Spawn", 0, BossSettings.EmergeDuration)
	task.spawn(runAI, boss)

	bossAnnouncement:FireAllClients({
		Kind = "Spawned",
		BossName = def.Name,
		BossTitle = def.Title,
		BossRarity = def.Rarity,
	})
	spawnedEvent:Fire(model, def)
	print(`[Bosses] {def.Name} ({def.Rarity}) emerged - {stats.MaxHealth} HP, {stats.Damage} dmg, scale {string.format("%.2f", stats.Scale)}, speed {humanoid.WalkSpeed}`)
	return model
end

-- Removes the active boss without loot (admin/testing).
function BossService.Despawn(reason: string?)
	local boss = current
	if not boss then
		return
	end
	boss.Alive = false
	release(boss, reason or "Despawned")
	boss.Model:Destroy()
end

function BossService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastNotice[player] = nil
		local boss = current
		if boss then
			boss.RecentAttackers[player] = nil
		end
	end)

	local chances = BossRoster.GetSpawnChances()
	local lines = {}
	for _, rarityName in Rarities.Order do
		for _, def in BossRoster.ByRarity[rarityName] do
			local stats = BossRoster.GetStats(def)
			table.insert(lines, string.format("  %-22s %-10s %6.2f%%  %7d HP  speed %d", def.Name, def.Rarity, chances[def.Id], stats.MaxHealth, def.WalkSpeed))
		end
	end
	print("[Bosses] Spawn table:\n" .. table.concat(lines, "\n"))
end

return BossService
