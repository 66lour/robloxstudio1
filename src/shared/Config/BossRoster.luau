--!strict
-- The 15 world bosses.
--
-- Scaling: a boss's final HP, damage and size are its rarity's base values
-- (see Rarities.luau) times its own modifiers, which must stay within
-- [0.9, 1.1]. The tier gaps are wider than that, so rarer bosses always come
-- out stronger and bigger. The check at the bottom of this file enforces it.
--
-- Spawning: first a rarity tier is picked by SpawnWeight, then a boss within
-- that tier by the boss's own SpawnWeight (default 1). GetSpawnChances()
-- returns the resulting percentage for each boss.
--
-- Abilities: `Abilities` entries are active skills with cooldowns and
-- `Passives` trigger by themselves. Missing parameters fall back to the
-- defaults in ServerScriptService.Server.Bosses.BossAbilities.

local ItemCatalog = require(script.Parent.ItemCatalog)
local Rarities = require(script.Parent.Rarities)

type RarityName = Rarities.RarityName

export type HeadShape = "Block" | "Ball" | "Skull" | "Pumpkin"
export type Feature = "Horns" | "Crown" | "Hood" | "Wings" | "Halo" | "Spikes" | "Pauldrons" | "FloatingOrbs" | "Floating"

export type Appearance = {
	Body: Color3,
	Accent: Color3,
	Eyes: Color3,
	Material: Enum.Material,
	Head: HeadShape,
	Features: { Feature },
	Aura: Color3,
}

export type AbilitySpec = { [string]: any } -- { Kind = "Slam" | "Charge" | "Blink" | "Drain" | "Meteor" | "Nova", ...params }
export type PassiveSpec = { [string]: any } -- { Kind = "Enrage", ...params }

export type BossDef = {
	Id: string,
	Name: string,
	Title: string,
	Lore: string,
	Rarity: RarityName,
	SpawnWeight: number?, -- weight within its rarity tier, default 1
	HealthMod: number,
	DamageMod: number,
	ScaleMod: number,
	WalkSpeed: number,
	AttackCooldown: number,
	Appearance: Appearance,
	Abilities: { AbilitySpec },
	Passives: { PassiveSpec },
	-- Chance (0-1) that this boss's exclusive item joins the regular drops.
	ExclusiveDropChance: number,
}

export type BossStats = {
	MaxHealth: number,
	Damage: number,
	Scale: number,
}

local rgb = Color3.fromRGB

local BossRoster = {}

BossRoster.List = {
	-- ═══════════════════════════════ COMMON ═══════════════════════════════
	{
		Id = "cursed_skeleton",
		Name = "Cursed Skeleton",
		Title = "The Restless Bones",
		Lore = "A soldier buried without rites. The curse keeps him marching.",
		Rarity = "Common",
		HealthMod = 1.0,
		DamageMod = 1.0,
		ScaleMod = 1.0,
		WalkSpeed = 13,
		AttackCooldown = 1.6,
		Appearance = {
			Body = rgb(222, 214, 194),
			Accent = rgb(70, 58, 46),
			Eyes = rgb(120, 255, 160),
			Material = Enum.Material.SmoothPlastic,
			Head = "Skull",
			Features = { "Pauldrons" },
			Aura = rgb(90, 220, 130),
		},
		Abilities = {
			{ Kind = "Slam", Cooldown = 9, Radius = 10, Windup = 1.2, DamageMult = 1.5 },
		},
		Passives = {},
		ExclusiveDropChance = 0.10,
	},
	{
		Id = "rotting_ghoul",
		Name = "Rotting Ghoul",
		Title = "Glutton of the Catacombs",
		Lore = "It ate its way out of the ossuary and it is still hungry.",
		Rarity = "Common",
		HealthMod = 0.92,
		DamageMod = 1.08,
		ScaleMod = 0.95,
		WalkSpeed = 15,
		AttackCooldown = 1.3,
		Appearance = {
			Body = rgb(104, 122, 88),
			Accent = rgb(90, 40, 40),
			Eyes = rgb(255, 220, 90),
			Material = Enum.Material.Sand,
			Head = "Block",
			Features = { "Spikes" },
			Aura = rgb(150, 180, 70),
		},
		Abilities = {
			{ Kind = "Charge", Cooldown = 10, Speed = 38, Windup = 0.9, HitRadius = 5, DamageMult = 1.4 },
		},
		Passives = {},
		ExclusiveDropChance = 0.10,
	},
	{
		Id = "bog_hag",
		Name = "Bog Hag",
		Title = "Crone of the Drowned Mire",
		Lore = "She trades wishes for years of your life, and she always collects.",
		Rarity = "Common",
		HealthMod = 1.08,
		DamageMod = 0.92,
		ScaleMod = 1.05,
		WalkSpeed = 11,
		AttackCooldown = 1.8,
		Appearance = {
			Body = rgb(72, 92, 62),
			Accent = rgb(44, 54, 38),
			Eyes = rgb(200, 255, 120),
			Material = Enum.Material.Slate,
			Head = "Ball",
			Features = { "Hood" },
			Aura = rgb(120, 200, 90),
		},
		Abilities = {
			{ Kind = "Drain", Cooldown = 12, Duration = 3, Radius = 12, DamageMult = 0.35, HealRatio = 1.0 },
		},
		Passives = {},
		ExclusiveDropChance = 0.10,
	},

	-- ══════════════════════════════ UNCOMMON ══════════════════════════════
	{
		Id = "wraith_knight",
		Name = "Wraith Knight",
		Title = "Oathbreaker of the Pale Order",
		Lore = "He swore to guard the king forever. The king died; the oath did not.",
		Rarity = "Uncommon",
		HealthMod = 1.0,
		DamageMod = 1.05,
		ScaleMod = 1.0,
		WalkSpeed = 15,
		AttackCooldown = 1.4,
		Appearance = {
			Body = rgb(42, 46, 58),
			Accent = rgb(150, 172, 204),
			Eyes = rgb(120, 200, 255),
			Material = Enum.Material.Metal,
			Head = "Block",
			Features = { "Hood", "Pauldrons", "Floating" },
			Aura = rgb(110, 170, 255),
		},
		Abilities = {
			{ Kind = "Blink", Cooldown = 9, Radius = 8, Windup = 0.45, DamageMult = 1.6 },
			{ Kind = "Charge", Cooldown = 12, Speed = 42, Windup = 0.8, HitRadius = 6, DamageMult = 1.3 },
		},
		Passives = {},
		ExclusiveDropChance = 0.08,
	},
	{
		Id = "plague_rat_king",
		Name = "Plague Rat King",
		Title = "Sovereign of the Sewers",
		Lore = "A hundred rats knotted at the tail, wearing a crown of rusted coins.",
		Rarity = "Uncommon",
		HealthMod = 0.94,
		DamageMod = 0.95,
		ScaleMod = 0.92,
		WalkSpeed = 16,
		AttackCooldown = 1.2,
		Appearance = {
			Body = rgb(94, 82, 72),
			Accent = rgb(160, 150, 44),
			Eyes = rgb(255, 60, 60),
			Material = Enum.Material.Fabric,
			Head = "Ball",
			Features = { "Crown", "Spikes" },
			Aura = rgb(170, 200, 40),
		},
		Abilities = {
			{ Kind = "Meteor", Cooldown = 11, Count = 3, Radius = 7, Windup = 1.4, DamageMult = 1.3, Range = 50, Color = rgb(150, 210, 40) },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.4, DamageMult = 1.25, SpeedMult = 1.3, CooldownMult = 0.8 },
		},
		ExclusiveDropChance = 0.08,
	},
	{
		Id = "gravebound_golem",
		Name = "Gravebound Golem",
		Title = "The Walking Mausoleum",
		Lore = "Built from the tombs of a hundred heroes, it carries their names into battle.",
		Rarity = "Uncommon",
		HealthMod = 1.1,
		DamageMod = 1.0,
		ScaleMod = 1.1,
		WalkSpeed = 10,
		AttackCooldown = 2.0,
		Appearance = {
			Body = rgb(112, 112, 118),
			Accent = rgb(70, 210, 170),
			Eyes = rgb(70, 255, 210),
			Material = Enum.Material.Slate,
			Head = "Block",
			Features = { "Pauldrons", "Spikes" },
			Aura = rgb(70, 210, 170),
		},
		Abilities = {
			{ Kind = "Slam", Cooldown = 10, Radius = 14, Windup = 1.5, DamageMult = 1.9 },
			{ Kind = "Nova", Cooldown = 15, Radius = 16, Windup = 1.2, DamageMult = 0.8, SlowFactor = 0.6, SlowDuration = 3 },
		},
		Passives = {},
		ExclusiveDropChance = 0.08,
	},

	-- ════════════════════════════════ RARE ════════════════════════════════
	{
		Id = "pumpkin_lord",
		Name = "Ancient Pumpkin Lord",
		Title = "Harvester of Souls",
		Lore = "Every autumn he walks the fields, and every autumn the scarecrows are new.",
		Rarity = "Rare",
		HealthMod = 1.05,
		DamageMod = 1.0,
		ScaleMod = 1.05,
		WalkSpeed = 14,
		AttackCooldown = 1.5,
		Appearance = {
			Body = rgb(34, 26, 22),
			Accent = rgb(240, 120, 20),
			Eyes = rgb(255, 200, 60),
			Material = Enum.Material.Fabric,
			Head = "Pumpkin",
			Features = { "Pauldrons", "Hood" },
			Aura = rgb(255, 130, 30),
		},
		Abilities = {
			{ Kind = "Meteor", Cooldown = 10, Count = 4, Radius = 8, Windup = 1.3, DamageMult = 1.4, Range = 60, Color = rgb(255, 120, 20) },
			{ Kind = "Charge", Cooldown = 13, Speed = 40, Windup = 0.9, HitRadius = 7, DamageMult = 1.3 },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.5, DamageMult = 1.3, SpeedMult = 1.2, CooldownMult = 0.8 },
		},
		ExclusiveDropChance = 0.06,
	},
	{
		Id = "bloodmoon_werewolf",
		Name = "Bloodmoon Werewolf",
		Title = "The Howl Beneath the Red Moon",
		Lore = "Once a village huntsman. Now the village is what he hunts.",
		Rarity = "Rare",
		HealthMod = 0.9,
		DamageMod = 1.1,
		ScaleMod = 0.95,
		WalkSpeed = 20,
		AttackCooldown = 1.0,
		Appearance = {
			Body = rgb(72, 52, 42),
			Accent = rgb(180, 30, 30),
			Eyes = rgb(255, 40, 40),
			Material = Enum.Material.Fabric,
			Head = "Block",
			Features = { "Horns", "Spikes" },
			Aura = rgb(200, 30, 40),
		},
		Abilities = {
			{ Kind = "Charge", Cooldown = 7, Speed = 52, Windup = 0.6, HitRadius = 6, DamageMult = 1.3 },
			{ Kind = "Blink", Cooldown = 11, Radius = 9, Windup = 0.35, DamageMult = 1.5 },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.5, DamageMult = 1.2, SpeedMult = 1.4, CooldownMult = 0.7 },
		},
		ExclusiveDropChance = 0.06,
	},
	{
		Id = "crypt_lich",
		Name = "Crypt Lich",
		Title = "Keeper of the Black Phylactery",
		Lore = "He bargained away his death. Now he spends his eternity guarding the receipt.",
		Rarity = "Rare",
		HealthMod = 1.0,
		DamageMod = 1.05,
		ScaleMod = 1.0,
		WalkSpeed = 12,
		AttackCooldown = 1.7,
		Appearance = {
			Body = rgb(62, 42, 82),
			Accent = rgb(170, 255, 220),
			Eyes = rgb(90, 255, 230),
			Material = Enum.Material.Fabric,
			Head = "Skull",
			Features = { "Crown", "Hood", "FloatingOrbs", "Floating" },
			Aura = rgb(120, 255, 220),
		},
		Abilities = {
			{ Kind = "Meteor", Cooldown = 9, Count = 5, Radius = 6, Windup = 1.2, DamageMult = 1.1, Range = 70, Color = rgb(110, 255, 220) },
			{ Kind = "Nova", Cooldown = 14, Radius = 18, Windup = 1.3, DamageMult = 0.9, SlowFactor = 0.5, SlowDuration = 3 },
			{ Kind = "Drain", Cooldown = 16, Duration = 3, Radius = 14, DamageMult = 0.4, HealRatio = 1.5 },
		},
		Passives = {},
		ExclusiveDropChance = 0.06,
	},

	-- ════════════════════════════════ EPIC ════════════════════════════════
	{
		Id = "frostbound_banshee",
		Name = "Frostbound Banshee",
		Title = "The Keening Bride",
		Lore = "Jilted at the altar of a frozen chapel, she still waits in her wedding shroud.",
		Rarity = "Epic",
		HealthMod = 0.95,
		DamageMod = 1.05,
		ScaleMod = 0.95,
		WalkSpeed = 16,
		AttackCooldown = 1.4,
		Appearance = {
			Body = rgb(196, 220, 240),
			Accent = rgb(80, 140, 210),
			Eyes = rgb(210, 240, 255),
			Material = Enum.Material.Ice,
			Head = "Ball",
			Features = { "Hood", "Floating", "FloatingOrbs" },
			Aura = rgb(150, 210, 255),
		},
		Abilities = {
			{ Kind = "Nova", Cooldown = 11, Radius = 22, Windup = 1.4, DamageMult = 1.2, SlowFactor = 0.45, SlowDuration = 4 },
			{ Kind = "Blink", Cooldown = 9, Radius = 10, Windup = 0.4, DamageMult = 1.5 },
			{ Kind = "Drain", Cooldown = 18, Duration = 3.5, Radius = 16, DamageMult = 0.4, HealRatio = 1.2 },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.35, DamageMult = 1.35, SpeedMult = 1.25, CooldownMult = 0.75 },
		},
		ExclusiveDropChance = 0.05,
	},
	{
		Id = "abyssal_warden",
		Name = "Abyssal Warden",
		Title = "Jailer of the Drowned Abyss",
		Lore = "It guards a prison at the bottom of the sea. Nobody knows what is locked inside.",
		Rarity = "Epic",
		HealthMod = 1.1,
		DamageMod = 0.95,
		ScaleMod = 1.1,
		WalkSpeed = 12,
		AttackCooldown = 1.8,
		Appearance = {
			Body = rgb(22, 32, 44),
			Accent = rgb(40, 210, 210),
			Eyes = rgb(60, 255, 240),
			Material = Enum.Material.Basalt,
			Head = "Block",
			Features = { "Horns", "Spikes", "Pauldrons" },
			Aura = rgb(40, 200, 210),
		},
		Abilities = {
			{ Kind = "Slam", Cooldown = 9, Radius = 18, Windup = 1.4, DamageMult = 1.8 },
			{ Kind = "Charge", Cooldown = 12, Speed = 40, Windup = 1.0, HitRadius = 9, DamageMult = 1.4 },
			{ Kind = "Meteor", Cooldown = 14, Count = 4, Radius = 9, Windup = 1.5, DamageMult = 1.3, Range = 70, Color = rgb(40, 210, 210) },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.4, DamageMult = 1.3, SpeedMult = 1.2, CooldownMult = 0.8 },
		},
		ExclusiveDropChance = 0.05,
	},

	-- ═════════════════════════════ LEGENDARY ══════════════════════════════
	{
		Id = "infernal_colossus",
		Name = "Infernal Colossus",
		Title = "The Forge That Walks",
		Lore = "A furnace given legs by a desperate blacksmith-king. It never stopped burning.",
		Rarity = "Legendary",
		HealthMod = 1.1,
		DamageMod = 1.0,
		ScaleMod = 1.1,
		WalkSpeed = 11,
		AttackCooldown = 1.9,
		Appearance = {
			Body = rgb(42, 32, 30),
			Accent = rgb(255, 110, 30),
			Eyes = rgb(255, 190, 50),
			Material = Enum.Material.Basalt,
			Head = "Block",
			Features = { "Horns", "Pauldrons", "Spikes" },
			Aura = rgb(255, 100, 20),
		},
		Abilities = {
			{ Kind = "Slam", Cooldown = 8, Radius = 22, Windup = 1.5, DamageMult = 2.0 },
			{ Kind = "Meteor", Cooldown = 12, Count = 6, Radius = 10, Windup = 1.6, DamageMult = 1.5, Range = 80, Color = rgb(255, 90, 20) },
			{ Kind = "Charge", Cooldown = 15, Speed = 38, Windup = 1.1, HitRadius = 11, DamageMult = 1.5 },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.5, DamageMult = 1.3, SpeedMult = 1.3, CooldownMult = 0.75 },
		},
		ExclusiveDropChance = 0.04,
	},
	{
		Id = "eclipse_seraph",
		Name = "The Eclipse Seraph",
		Title = "Fallen Light of the Black Sun",
		Lore = "Heaven's brightest herald flew too close to the dark side of the sun.",
		Rarity = "Legendary",
		HealthMod = 0.95,
		DamageMod = 1.1,
		ScaleMod = 0.95,
		WalkSpeed = 17,
		AttackCooldown = 1.3,
		Appearance = {
			Body = rgb(28, 24, 34),
			Accent = rgb(255, 204, 96),
			Eyes = rgb(255, 220, 120),
			Material = Enum.Material.Marble,
			Head = "Ball",
			Features = { "Wings", "Halo", "Floating" },
			Aura = rgb(255, 196, 80),
		},
		Abilities = {
			{ Kind = "Blink", Cooldown = 7, Radius = 11, Windup = 0.35, DamageMult = 1.6 },
			{ Kind = "Nova", Cooldown = 12, Radius = 24, Windup = 1.3, DamageMult = 1.3, SlowFactor = 0.5, SlowDuration = 3 },
			{ Kind = "Meteor", Cooldown = 14, Count = 6, Radius = 9, Windup = 1.4, DamageMult = 1.5, Range = 80, Color = rgb(255, 200, 80) },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.4, DamageMult = 1.35, SpeedMult = 1.25, CooldownMult = 0.7 },
		},
		ExclusiveDropChance = 0.04,
	},

	-- ═══════════════════════════════ MYTHIC ═══════════════════════════════
	{
		Id = "nyxthal",
		Name = "Nyx'thal",
		Title = "Maw of the Starless Void",
		Lore = "Astronomers noticed the stars going out one by one. Then they noticed the teeth.",
		Rarity = "Mythic",
		HealthMod = 1.1,
		DamageMod = 1.0,
		ScaleMod = 1.1,
		WalkSpeed = 13,
		AttackCooldown = 1.6,
		Appearance = {
			Body = rgb(16, 12, 26),
			Accent = rgb(190, 60, 255),
			Eyes = rgb(255, 60, 230),
			Material = Enum.Material.Glass,
			Head = "Ball",
			Features = { "Horns", "Wings", "FloatingOrbs", "Spikes", "Floating" },
			Aura = rgb(170, 50, 255),
		},
		Abilities = {
			{ Kind = "Drain", Cooldown = 14, Duration = 4, Radius = 24, DamageMult = 0.5, HealRatio = 2.0 },
			{ Kind = "Meteor", Cooldown = 10, Count = 8, Radius = 11, Windup = 1.5, DamageMult = 1.6, Range = 90, Color = rgb(180, 60, 255) },
			{ Kind = "Nova", Cooldown = 13, Radius = 28, Windup = 1.5, DamageMult = 1.4, SlowFactor = 0.4, SlowDuration = 4 },
			{ Kind = "Blink", Cooldown = 9, Radius = 12, Windup = 0.4, DamageMult = 1.7 },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.3, DamageMult = 1.5, SpeedMult = 1.3, CooldownMult = 0.6 },
		},
		ExclusiveDropChance = 0.03,
	},
	{
		Id = "pale_king",
		Name = "The Pale King",
		Title = "Sovereign of the Dreaming Dead",
		Lore = "He rules a kingdom that exists only while its subjects sleep. Tonight, you are dreaming.",
		Rarity = "Mythic",
		HealthMod = 1.0,
		DamageMod = 1.1,
		ScaleMod = 1.0,
		WalkSpeed = 15,
		AttackCooldown = 1.4,
		Appearance = {
			Body = rgb(232, 230, 222),
			Accent = rgb(200, 30, 50),
			Eyes = rgb(255, 40, 60),
			Material = Enum.Material.Marble,
			Head = "Skull",
			Features = { "Crown", "Pauldrons", "Hood", "Halo" },
			Aura = rgb(230, 40, 60),
		},
		Abilities = {
			{ Kind = "Slam", Cooldown = 8, Radius = 24, Windup = 1.4, DamageMult = 2.1 },
			{ Kind = "Charge", Cooldown = 11, Speed = 50, Windup = 0.8, HitRadius = 10, DamageMult = 1.6 },
			{ Kind = "Blink", Cooldown = 9, Radius = 12, Windup = 0.35, DamageMult = 1.8 },
			{ Kind = "Meteor", Cooldown = 13, Count = 7, Radius = 10, Windup = 1.4, DamageMult = 1.6, Range = 90, Color = rgb(230, 30, 60) },
		},
		Passives = {
			{ Kind = "Enrage", Threshold = 0.5, DamageMult = 1.4, SpeedMult = 1.3, CooldownMult = 0.65 },
		},
		ExclusiveDropChance = 0.03,
	},
} :: { BossDef }

BossRoster.ById = {} :: { [string]: BossDef }
BossRoster.ByRarity = {} :: { [RarityName]: { BossDef } }

for _, rarityName in Rarities.Order do
	BossRoster.ByRarity[rarityName] = {}
end

local MOD_MIN, MOD_MAX = 0.9, 1.1
local KNOWN_ABILITIES = { Slam = true, Charge = true, Blink = true, Drain = true, Meteor = true, Nova = true }
local KNOWN_PASSIVES = { Enrage = true }

for _, def in BossRoster.List do
	assert(BossRoster.ById[def.Id] == nil, `Duplicate boss id "{def.Id}"`)
	assert(Rarities.IsValid(def.Rarity), `Boss "{def.Id}" has an invalid Rarity`)
	for _, field in { "HealthMod", "DamageMod", "ScaleMod" } do
		local value = (def :: any)[field]
		assert(value >= MOD_MIN and value <= MOD_MAX, `Boss "{def.Id}" {field} must be within [{MOD_MIN}, {MOD_MAX}]`)
	end
	for _, ability in def.Abilities do
		assert(KNOWN_ABILITIES[ability.Kind], `Boss "{def.Id}" has unknown ability "{tostring(ability.Kind)}"`)
	end
	for _, passive in def.Passives do
		assert(KNOWN_PASSIVES[passive.Kind], `Boss "{def.Id}" has unknown passive "{tostring(passive.Kind)}"`)
	end
	assert(
		ItemCatalog.ExclusivesBySource[def.Id] ~= nil,
		`Boss "{def.Id}" has no exclusive item in ItemCatalog (Source = "{def.Id}")`
	)

	BossRoster.ById[def.Id] = def
	table.insert(BossRoster.ByRarity[def.Rarity], def)
end

-- Every exclusive item must belong to a boss that exists.
for sourceId in ItemCatalog.ExclusivesBySource do
	assert(BossRoster.ById[sourceId], `ItemCatalog exclusive references unknown boss "{sourceId}"`)
end

function BossRoster.Get(id: string): BossDef?
	return BossRoster.ById[id]
end

-- Final combat stats for a boss (rarity base values x the boss's modifiers).
function BossRoster.GetStats(def: BossDef): BossStats
	local rarity = Rarities.Get(def.Rarity)
	return {
		MaxHealth = math.floor(rarity.BaseHealth * def.HealthMod),
		Damage = math.floor(rarity.BaseDamage * def.DamageMod + 0.5),
		Scale = rarity.BaseScale * def.ScaleMod,
	}
end

-- Check that every stat increases with rarity: the weakest boss of a tier must
-- beat the strongest boss of the tier below it.
do
	local previousMax: BossStats? = nil
	local previousTier = ""
	for _, rarityName in Rarities.Order do
		local bosses = BossRoster.ByRarity[rarityName]
		if #bosses > 0 then
			local tierMin = { MaxHealth = math.huge, Damage = math.huge, Scale = math.huge }
			local tierMax = { MaxHealth = 0, Damage = 0, Scale = 0 }
			for _, def in bosses do
				local stats = BossRoster.GetStats(def) :: any
				for key in tierMin do
					tierMin[key] = math.min(tierMin[key], stats[key])
					tierMax[key] = math.max(tierMax[key], stats[key])
				end
			end
			if previousMax then
				for key, value in tierMin do
					assert(
						value > (previousMax :: any)[key],
						`Scaling broken: weakest {rarityName} boss {key} ({value}) is not above strongest {previousTier} ({(previousMax :: any)[key]})`
					)
				end
			end
			previousMax = tierMax :: any
			previousTier = rarityName
		end
	end
end

-- Percentage chance (0-100) that a spawn roll picks each boss, keyed by boss id.
function BossRoster.GetSpawnChances(): { [string]: number }
	local totalTierWeight = 0
	for _, rarityName in Rarities.Order do
		if #BossRoster.ByRarity[rarityName] > 0 then
			totalTierWeight += Rarities.Get(rarityName).SpawnWeight
		end
	end

	local chances = {}
	for _, rarityName in Rarities.Order do
		local bosses = BossRoster.ByRarity[rarityName]
		local tierWeight = 0
		for _, def in bosses do
			tierWeight += def.SpawnWeight or 1
		end
		local tierChance = Rarities.Get(rarityName).SpawnWeight / totalTierWeight
		for _, def in bosses do
			chances[def.Id] = tierChance * ((def.SpawnWeight or 1) / tierWeight) * 100
		end
	end
	return chances
end

-- Picks a random boss using the rarity and per-boss spawn weights.
function BossRoster.RollBoss(rng: Random): BossDef
	local totalTierWeight = 0
	for _, rarityName in Rarities.Order do
		if #BossRoster.ByRarity[rarityName] > 0 then
			totalTierWeight += Rarities.Get(rarityName).SpawnWeight
		end
	end

	local roll = rng:NextNumber() * totalTierWeight
	local chosenTier: { BossDef }? = nil
	for _, rarityName in Rarities.Order do
		local bosses = BossRoster.ByRarity[rarityName]
		if #bosses > 0 then
			chosenTier = bosses
			roll -= Rarities.Get(rarityName).SpawnWeight
			if roll < 0 then
				break
			end
		end
	end
	assert(chosenTier, "BossRoster is empty")

	local tierWeight = 0
	for _, def in chosenTier do
		tierWeight += def.SpawnWeight or 1
	end
	local bossRoll = rng:NextNumber() * tierWeight
	for _, def in chosenTier do
		bossRoll -= def.SpawnWeight or 1
		if bossRoll < 0 then
			return def
		end
	end
	return chosenTier[#chosenTier]
end

return BossRoster
