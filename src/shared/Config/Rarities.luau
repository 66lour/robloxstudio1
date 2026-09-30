--!strict
-- Rarity tiers shared by bosses and collectible items.
-- A boss's base stats come from its tier. BossRoster checks at load time that
-- every stat keeps increasing from one tier to the next.

-- One of Rarities.Order: "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic".
-- Checked at load time by the config modules (see Rarities.IsValid).
export type RarityName = string

export type RarityInfo = {
	Name: RarityName,
	Rank: number,
	Color: Color3, -- primary UI / glow color
	AccentColor: Color3, -- secondary color for gradients and shimmer
	-- Relative weight of this tier when the spawner picks a boss. The tier's
	-- weight is shared between every boss in the tier. The weights add up to
	-- 100, so they read as percentages.
	SpawnWeight: number,
	-- Base boss stats for this tier. Each boss can adjust them by up to +/-10%.
	-- HP is tuned for the weapon ladder in WeaponCatalog (5 damage starter up to
	-- 1000 damage Reaper's Mythic Blade), so higher tiers need a group.
	BaseHealth: number,
	BaseDamage: number,
	BaseScale: number, -- 1 = regular character size
}

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } :: { RarityName }

Rarities.Info = {
	Common = {
		Name = "Common",
		Rank = 1,
		Color = Color3.fromRGB(176, 168, 152),
		AccentColor = Color3.fromRGB(110, 104, 94),
		SpawnWeight = 48,
		BaseHealth = 5000,
		BaseDamage = 12,
		BaseScale = 1.5,
	},
	Uncommon = {
		Name = "Uncommon",
		Rank = 2,
		Color = Color3.fromRGB(104, 196, 118),
		AccentColor = Color3.fromRGB(38, 110, 64),
		SpawnWeight = 27,
		BaseHealth = 9000,
		BaseDamage = 18,
		BaseScale = 2.0,
	},
	Rare = {
		Name = "Rare",
		Rank = 3,
		Color = Color3.fromRGB(86, 150, 240),
		AccentColor = Color3.fromRGB(30, 62, 140),
		SpawnWeight = 15,
		BaseHealth = 16500,
		BaseDamage = 26,
		BaseScale = 2.6,
	},
	Epic = {
		Name = "Epic",
		Rank = 4,
		Color = Color3.fromRGB(178, 96, 240),
		AccentColor = Color3.fromRGB(84, 30, 140),
		SpawnWeight = 6,
		BaseHealth = 30000,
		BaseDamage = 38,
		BaseScale = 3.3,
	},
	Legendary = {
		Name = "Legendary",
		Rank = 5,
		Color = Color3.fromRGB(244, 178, 64),
		AccentColor = Color3.fromRGB(160, 82, 18),
		SpawnWeight = 3,
		BaseHealth = 55000,
		BaseDamage = 55,
		BaseScale = 4.2,
	},
	Mythic = {
		Name = "Mythic",
		Rank = 6,
		Color = Color3.fromRGB(236, 54, 76),
		AccentColor = Color3.fromRGB(255, 140, 90),
		SpawnWeight = 1,
		BaseHealth = 100000,
		BaseDamage = 80,
		BaseScale = 5.5,
	},
} :: { [RarityName]: RarityInfo }

function Rarities.Get(name: RarityName): RarityInfo
	local info = Rarities.Info[name]
	assert(info, `Unknown rarity "{tostring(name)}"`)
	return info
end

function Rarities.Rank(name: RarityName): number
	return Rarities.Get(name).Rank
end

function Rarities.IsValid(name: any): boolean
	return type(name) == "string" and Rarities.Info[name :: RarityName] ~= nil
end

return Rarities
