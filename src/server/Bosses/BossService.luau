--!strict
-- Spawns world bosses, runs their AI and hands kills to LootService.
--
-- Spawning: every SpawnInterval seconds, while fewer than MaxActiveBosses are
-- alive and at least one player is in the server, a boss is rolled from
-- BossRoster (rarity weights, then boss weights) and placed at a free spawn
-- point.
--
-- AI: chase the nearest player in aggro range, use a ready ability that fits
-- the distance, otherwise melee. A boss pulled past its leash walks home. After
-- 20 seconds without a target it regenerates, and once back to full health its
-- damage tags are cleared (a fresh fight).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DamageTracker = require(script.Parent.Parent.Services.DamageTracker)
local LootService = require(script.Parent.Parent.Services.LootService)
local BossAbilities = require(script.Parent.BossAbilities)
local BossBuilder = require(script.Parent.BossBuilder)
local BossEffects = require(script.Parent.BossEffects)
local BossSettings = require(script.Parent.BossSettings)

type BossDef = BossRoster.BossDef
type BossStats = BossRoster.BossStats

type ActiveBoss = {
	Def: BossDef,
	Stats: BossStats,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Home: Vector3,
	SpawnPoint: BasePart?,
	Alive: boolean,
	Returning: boolean,
	DamageMult: number,
	SpeedMult: number,
	CooldownMult: number,
	Abilities: { { [string]: any } },
	ReadyAt: { [any]: number },
	NextAttack: number,
	LastCombat: number,
	TriggeredPassives: { [any]: boolean },
}

local OUT_OF_COMBAT_REGEN_DELAY = 20
local OUT_OF_COMBAT_REGEN_RATE = 0.05 -- share of max health per second
local ENRAGE_TINT = Color3.fromRGB(255, 40, 30)

local BossService = {}

local rng = Random.new()
local active: { [Model]: ActiveBoss } = {}
local bossAnnouncement = Remotes.Get("BossAnnouncement")

local bossFolder = Instance.new("Folder")
bossFolder.Name = "Bosses"
bossFolder.Parent = Workspace

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function countActive(): number
	local count = 0
	for _ in active do
		count += 1
	end
	return count
end

-- Spawning ------------------------------------------------------------------

local function getSpawnPoints(): { BasePart }
	local points = {}
	local folder = Workspace:FindFirstChild(BossSettings.SpawnFolderName)
	if folder then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(points, descendant)
			end
		end
	end
	return points
end

local function chooseSpawn(): (Vector3, BasePart?)
	local points = getSpawnPoints()
	if #points > 0 then
		local occupied: { [BasePart]: boolean } = {}
		for _, boss in active do
			if boss.SpawnPoint then
				occupied[boss.SpawnPoint] = true
			end
		end
		local free = {}
		for _, point in points do
			if not occupied[point] then
				table.insert(free, point)
			end
		end
		local pool = if #free > 0 then free else points
		local point = pool[rng:NextInteger(1, #pool)]
		return point.Position, point
	end

	local angle = rng:NextNumber() * math.pi * 2
	local radius = BossSettings.FallbackSpawnRadius
	return Vector3.new(math.cos(angle) * radius, 20, math.sin(angle) * radius), nil
end

-- Height of the root part above the ground when standing.
local function standingHeight(model: Model, humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	return root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
end

-- Passives ------------------------------------------------------------------

local function tintAura(boss: ActiveBoss, color: Color3)
	for _, descendant in boss.Model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name == "Aura" then
			descendant.Color = ColorSequence.new(color)
		elseif descendant:IsA("PointLight") and descendant.Name == "AuraLight" then
			descendant.Color = color
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
				humanoid.WalkSpeed = boss.Def.WalkSpeed * boss.SpeedMult
				tintAura(boss, boss.Def.Appearance.Aura:Lerp(ENRAGE_TINT, 0.6))
				BossEffects.Shockwave(boss.Root.Position, 10 * boss.Stats.Scale, ENRAGE_TINT)
				boss.Model:SetAttribute("Enraged", true)
			end
		end
	end
end

-- Undoes enrage after the boss fully resets out of combat.
local function resetPassives(boss: ActiveBoss)
	if next(boss.TriggeredPassives) == nil then
		return
	end
	boss.TriggeredPassives = {}
	boss.DamageMult, boss.SpeedMult, boss.CooldownMult = 1, 1, 1
	boss.Humanoid.WalkSpeed = boss.Def.WalkSpeed
	tintAura(boss, boss.Def.Appearance.Aura)
	boss.Model:SetAttribute("Enraged", nil)
end

-- AI ------------------------------------------------------------------------

local function findTarget(boss: ActiveBoss): (BasePart?, number)
	local aggroRange = BossSettings.AggroRange + 6 * boss.Stats.Scale
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - boss.Root.Position).Magnitude
			local fromHome = flat(root.Position - boss.Home).Magnitude
			if distance <= aggroRange and fromHome <= BossSettings.LeashRange and distance < bestDistance then
				bestRoot = root
				bestDistance = distance
			end
		end
	end
	return bestRoot, bestDistance
end

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
			return boss.Def.WalkSpeed * boss.SpeedMult
		end,
		IsAlive = function()
			return boss.Alive and boss.Model.Parent ~= nil
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

local function melee(boss: ActiveBoss, targetRoot: BasePart)
	boss.NextAttack = os.clock() + boss.Def.AttackCooldown * boss.CooldownMult
	boss.Humanoid:MoveTo(boss.Root.Position)
	face(boss, targetRoot.Position)
	task.wait(BossSettings.MeleeWindup)
	if not boss.Alive or not targetRoot.Parent then
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
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * OUT_OF_COMBAT_REGEN_RATE * dt)
	if humanoid.Health >= humanoid.MaxHealth then
		DamageTracker.ClearTags(boss.Model)
		resetPassives(boss)
	end
end

local function think(boss: ActiveBoss)
	local now = os.clock()
	local humanoid = boss.Humanoid
	local toHome = flat(boss.Home - boss.Root.Position).Magnitude

	if toHome > BossSettings.LeashRange then
		boss.Returning = true
	end
	if boss.Returning then
		if toHome < 10 then
			boss.Returning = false
		else
			humanoid:MoveTo(boss.Home)
			return
		end
	end

	local targetRoot, distance = findTarget(boss)
	if not targetRoot then
		if toHome > 6 then
			humanoid:MoveTo(boss.Home)
		end
		if now - boss.LastCombat > OUT_OF_COMBAT_REGEN_DELAY then
			regenerate(boss, BossSettings.ThinkInterval)
		end
		return
	end

	boss.LastCombat = now
	local spec = pickAbility(boss, distance)
	if spec then
		boss.ReadyAt[spec] = now + spec.Cooldown * boss.CooldownMult
		BossAbilities.Run(makeContext(boss, targetRoot), spec)
		-- Short breather after an ability before the next melee swing.
		boss.NextAttack = math.max(boss.NextAttack, os.clock() + 0.6)
		return
	end

	local reach = BossSettings.MeleeReach + 2 * boss.Stats.Scale
	if distance <= reach then
		if now >= boss.NextAttack then
			melee(boss, targetRoot)
		else
			humanoid:MoveTo(boss.Root.Position)
			face(boss, targetRoot.Position)
		end
	else
		humanoid:MoveTo(targetRoot.Position)
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

-- Death -----------------------------------------------------------------------

local function onDied(boss: ActiveBoss)
	if not boss.Alive then
		return
	end
	boss.Alive = false
	local position = boss.Root.Position

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

	active[boss.Model] = nil
	task.delay(BossSettings.CorpseDuration + 0.5, function()
		boss.Model:Destroy()
	end)
end

-- Public API ------------------------------------------------------------------

-- Spawns a boss. Pass a boss id to force one (e.g. from an admin command);
-- otherwise one is rolled by spawn weight.
function BossService.Spawn(bossId: string?): Model
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

	local spawnPosition, spawnPoint = chooseSpawn()
	local ground = BossEffects.GroundAt(spawnPosition)
	local height = standingHeight(model, humanoid, root)
	local yaw = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, height, 0)) * yaw)
	model.Parent = bossFolder
	root:SetNetworkOwner(nil)

	local now = os.clock()
	local boss: ActiveBoss = {
		Def = def,
		Stats = stats,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Home = root.Position,
		SpawnPoint = spawnPoint,
		Alive = true,
		Returning = false,
		DamageMult = 1,
		SpeedMult = 1,
		CooldownMult = 1,
		Abilities = {},
		ReadyAt = {},
		NextAttack = now,
		LastCombat = now,
		TriggeredPassives = {},
	}
	for _, rawSpec in def.Abilities do
		local spec = BossAbilities.Resolve(rawSpec)
		table.insert(boss.Abilities, spec)
		-- Stagger first casts so a boss doesn't open with every ability at once.
		boss.ReadyAt[spec] = now + rng:NextNumber(2, math.max(3, spec.Cooldown * 0.6))
	end
	active[model] = boss

	DamageTracker.Track(model)
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function()
		local health = humanoid.Health
		if health < lastHealth then
			-- Taking damage counts as combat even from outside aggro range, so
			-- ranged attackers can't be undone by out-of-combat regen.
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
		if parent == nil and active[model] == boss then
			-- Removed without dying (e.g. fell out of the world).
			boss.Alive = false
			active[model] = nil
		end
	end)

	task.spawn(runAI, boss)

	bossAnnouncement:FireAllClients({
		Kind = "Spawned",
		BossName = def.Name,
		BossTitle = def.Title,
		BossRarity = def.Rarity,
	})
	print(`[Bosses] Spawned {def.Name} ({def.Rarity}) - {stats.MaxHealth} HP, {stats.Damage} dmg, scale {stats.Scale}`)
	return model
end

function BossService.GetActiveCount(): number
	return countActive()
end

function BossService.Start()
	local chances = BossRoster.GetSpawnChances()
	local lines = {}
	for _, rarityName in Rarities.Order do
		for _, def in BossRoster.ByRarity[rarityName] do
			table.insert(lines, string.format("  %-22s %-10s %6.2f%%", def.Name, def.Rarity, chances[def.Id]))
		end
	end
	print("[Bosses] Spawn table:\n" .. table.concat(lines, "\n"))

	task.spawn(function()
		task.wait(BossSettings.FirstSpawnDelay)
		while true do
			if countActive() < BossSettings.MaxActiveBosses and #Players:GetPlayers() > 0 then
				local ok, err = pcall(BossService.Spawn)
				if not ok then
					warn(`[Bosses] Spawn failed: {err}`)
				end
			end
			task.wait(BossSettings.SpawnInterval)
		end
	end)
end

return BossService
