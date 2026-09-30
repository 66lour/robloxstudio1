--!strict
-- Rolls a boss's drops. Contains no Roblox services, so it runs the same
-- anywhere, but only the server should call it (clients can't be trusted with
-- loot).

local Config = script.Parent.Config
local BossRoster = require(Config.BossRoster)
local ItemCatalog = require(Config.ItemCatalog)
local LootTables = require(Config.LootTables)
local Rarities = require(Config.Rarities)

type BossDef = BossRoster.BossDef
type ItemDef = ItemCatalog.ItemDef

local LootRoller = {}

local function weightedPick<T>(rng: Random, weights: { [T]: number }): T
	local total = 0
	-- Sort keys so the result for a given seed doesn't depend on table order.
	local keys = {}
	for key, weight in weights do
		total += weight
		table.insert(keys, key)
	end
	assert(total > 0, "weightedPick needs at least one positive weight")
	table.sort(keys :: { any }, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)

	local roll = rng:NextNumber() * total
	for _, key in keys do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return keys[#keys]
end

local function rollItemRarity(rng: Random, weights: { [Rarities.RarityName]: number }, minRank: number): Rarities.RarityName
	local allowed = {}
	for rarityName, weight in weights do
		if Rarities.Rank(rarityName) >= minRank then
			allowed[rarityName] = weight
		end
	end
	return weightedPick(rng, allowed)
end

-- Returns the drops for one kill of `def`, rarest first.
function LootRoller.Roll(def: BossDef, rng: Random): { ItemDef }
	local lootTable = LootTables.ByBossRarity[def.Rarity]
	local drops: { ItemDef } = {}

	for rollIndex = 1, lootTable.Rolls do
		local minRank = if rollIndex == 1 then Rarities.Rank(lootTable.Guaranteed) else 1
		local itemRarity = rollItemRarity(rng, lootTable.Weights, minRank)
		local itemType = weightedPick(rng, LootTables.TypeWeights :: { [ItemCatalog.ItemType]: number })
		local candidates = ItemCatalog.Pool[itemRarity][itemType]
		table.insert(drops, candidates[rng:NextInteger(1, #candidates)])
	end

	local exclusives = ItemCatalog.ExclusivesBySource[def.Id]
	if exclusives and rng:NextNumber() < def.ExclusiveDropChance then
		table.insert(drops, exclusives[rng:NextInteger(1, #exclusives)])
	end

	table.sort(drops, function(a, b)
		local rankA, rankB = Rarities.Rank(a.Rarity), Rarities.Rank(b.Rarity)
		if rankA ~= rankB then
			return rankA > rankB
		end
		if a.Exclusive ~= b.Exclusive then
			return a.Exclusive
		end
		return a.Id < b.Id
	end)

	return drops
end

return LootRoller
