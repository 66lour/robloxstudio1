-- Tests for the boss roster, scaling and loot rules.
-- Run from the repo root with Lune: lune run tests/run
local Harness = require("./harness")
local Random = Harness.Random
local shared = Harness.shared()

local Rarities = Harness.require(shared.Config.Rarities)
local ItemCatalog = Harness.require(shared.Config.ItemCatalog)
local BossRoster = Harness.require(shared.Config.BossRoster)
local LootTables = Harness.require(shared.Config.LootTables)
local LootRoller = Harness.require(shared.LootRoller)

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- Roster ------------------------------------------------------------------
check(#BossRoster.List == 15, `expected 15 bosses, got {#BossRoster.List}`)
local names = {}
for _, def in BossRoster.List do
	check(names[def.Name] == nil, `duplicate boss name {def.Name}`)
	names[def.Name] = true
end
for _, rarityName in Rarities.Order do
	check(#BossRoster.ByRarity[rarityName] > 0, `no bosses for {rarityName}`)
end

-- Spawn chances -----------------------------------------------------------
local chances = BossRoster.GetSpawnChances()
local total = 0
for _, pct in chances do
	total += pct
end
check(math.abs(total - 100) < 1e-6, `spawn chances sum to {total}`)

local rng = Random.new(1234)
local spawnCounts = {}
local SPAWN_TRIALS = 200000
for _ = 1, SPAWN_TRIALS do
	local def = BossRoster.RollBoss(rng)
	spawnCounts[def.Id] = (spawnCounts[def.Id] or 0) + 1
end

print("\nBoss                          Rarity     HP       Dmg  Scale  Spawn%  (observed)")
local previousTierMaxHP = 0
for _, def in BossRoster.List do
	local stats = BossRoster.GetStats(def)
	local observed = (spawnCounts[def.Id] or 0) / SPAWN_TRIALS * 100
	print(string.format("%-29s %-10s %-8d %-4d %-6.2f %-7.3f (%.3f)", def.Name, def.Rarity, stats.MaxHealth, stats.Damage, stats.Scale, chances[def.Id], observed))
	check(math.abs(observed - chances[def.Id]) < 0.35, `{def.Id} observed spawn {observed}% vs expected {chances[def.Id]}%`)
end

-- Every boss of a rarer tier is less likely to spawn than any boss of the tier below.
local previousMinChance = math.huge
for _, rarityName in Rarities.Order do
	local tierMin, tierMax = math.huge, 0
	for _, def in BossRoster.ByRarity[rarityName] do
		tierMin = math.min(tierMin, chances[def.Id])
		tierMax = math.max(tierMax, chances[def.Id])
	end
	check(tierMax < previousMinChance, `{rarityName} bosses should spawn less often than the tier below`)
	previousMinChance = tierMin
end

local tierWeightTotal = 0
for _, rarityName in Rarities.Order do
	tierWeightTotal += Rarities.Get(rarityName).SpawnWeight
end
check(tierWeightTotal == 100, `rarity spawn weights should sum to 100, got {tierWeightTotal}`)

-- Loot --------------------------------------------------------------------
print("\nAverage loot per kill (share of drops by item rarity):")
local header = string.format("%-11s", "Boss tier")
for _, r in Rarities.Order do
	header ..= string.format("%-10s", r)
end
print(header .. "Excl%")

local previousAvgRank = 0
for _, bossRarity in Rarities.Order do
	local lootTable = LootTables.ByBossRarity[bossRarity]
	local counts, totalDrops, exclusiveKills = {}, 0, 0
	local rankSum = 0
	local KILLS = 20000
	local lootRng = Random.new(99)
	for _, def in BossRoster.ByRarity[bossRarity] do
		for _ = 1, KILLS do
			local drops = LootRoller.Roll(def, lootRng)
			check(#drops >= lootTable.Rolls and #drops <= lootTable.Rolls + 1, "unexpected drop count")
			local guaranteedMet = false
			local sawExclusive = false
			for _, item in drops do
				check(ItemCatalog.Get(item.Id) == item, "drop is not a catalog item")
				counts[item.Rarity] = (counts[item.Rarity] or 0) + 1
				totalDrops += 1
				rankSum += Rarities.Rank(item.Rarity)
				if Rarities.Rank(item.Rarity) >= Rarities.Rank(lootTable.Guaranteed) then
					guaranteedMet = true
				end
				if item.Exclusive then
					sawExclusive = true
					check(item.Source == def.Id, `{def.Id} dropped another boss's exclusive`)
				end
			end
			check(guaranteedMet, `{def.Id} drop missed its guaranteed rarity`)
			if sawExclusive then
				exclusiveKills += 1
			end
		end
	end
	local line = string.format("%-11s", bossRarity)
	for _, r in Rarities.Order do
		line ..= string.format("%-10s", string.format("%.1f%%", (counts[r] or 0) / totalDrops * 100))
	end
	local kills = KILLS * #BossRoster.ByRarity[bossRarity]
	print(line .. string.format("%.1f", exclusiveKills / kills * 100))

	local avgRank = rankSum / totalDrops
	check(avgRank > previousAvgRank, `{bossRarity} bosses should drop rarer loot on average than the tier below`)
	previousAvgRank = avgRank
end

-- Seeds are deterministic.
local a = LootRoller.Roll(BossRoster.ById.pale_king, Random.new(7))
local b = LootRoller.Roll(BossRoster.ById.pale_king, Random.new(7))
check(#a == #b, "same seed should give the same drop count")
for i = 1, #a do
	check(a[i] == b[i], "same seed should give the same drops")
end

print("")
if failures > 0 then
	print(`{failures} check(s) failed`)
	error("tests failed")
end
print("All checks passed")
