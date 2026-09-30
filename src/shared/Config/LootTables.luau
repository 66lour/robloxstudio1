--!strict
-- Loot rules per boss rarity. Rarer bosses roll more items and their rolls
-- lean towards rarer items.
--
--   Rolls      – how many pool items the boss drops
--   Guaranteed – the minimum item rarity for the first roll
--   Weights    – relative weight of each item rarity for every roll
--
-- On top of these rolls, each boss can also drop its exclusive item
-- (BossRoster `ExclusiveDropChance`).

local Rarities = require(script.Parent.Rarities)

type RarityName = Rarities.RarityName

export type LootTable = {
	Rolls: number,
	Guaranteed: RarityName,
	Weights: { [RarityName]: number },
}

local LootTables = {}

LootTables.ByBossRarity = {
	Common = {
		Rolls = 1,
		Guaranteed = "Common",
		Weights = { Common = 75, Uncommon = 22, Rare = 3 },
	},
	Uncommon = {
		Rolls = 1,
		Guaranteed = "Uncommon",
		Weights = { Uncommon = 76, Rare = 20, Epic = 4 },
	},
	Rare = {
		Rolls = 2,
		Guaranteed = "Rare",
		Weights = { Uncommon = 35, Rare = 50, Epic = 13, Legendary = 2 },
	},
	Epic = {
		Rolls = 2,
		Guaranteed = "Epic",
		Weights = { Rare = 40, Epic = 48, Legendary = 11, Mythic = 1 },
	},
	Legendary = {
		Rolls = 3,
		Guaranteed = "Legendary",
		Weights = { Epic = 45, Legendary = 48, Mythic = 7 },
	},
	Mythic = {
		Rolls = 3,
		Guaranteed = "Mythic",
		Weights = { Epic = 15, Legendary = 55, Mythic = 30 },
	},
} :: { [RarityName]: LootTable }

-- Chance that each pool roll is a Pet rather than an Armor.
LootTables.TypeWeights = { Pet = 50, Armor = 50 }

for _, rarityName in Rarities.Order do
	local lootTable = LootTables.ByBossRarity[rarityName]
	assert(lootTable, `Missing loot table for {rarityName} bosses`)
	assert(lootTable.Rolls >= 1, `{rarityName} loot table needs at least one roll`)
	local guaranteedRank = Rarities.Rank(lootTable.Guaranteed)
	local hasGuaranteedOption = false
	for itemRarity, weight in lootTable.Weights do
		assert(Rarities.IsValid(itemRarity), `{rarityName} loot table has invalid rarity "{itemRarity}"`)
		assert(weight > 0, `{rarityName} loot table weight for {itemRarity} must be positive`)
		if Rarities.Rank(itemRarity) >= guaranteedRank then
			hasGuaranteedOption = true
		end
	end
	assert(hasGuaranteedOption, `{rarityName} loot table can never satisfy its Guaranteed rarity`)
end

return LootTables
