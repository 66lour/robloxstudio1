--!strict
-- Every weapon that can hurt bosses, weakest to strongest.
--
-- Damage is per hit and is applied by the server (WeaponService), never by a
-- script inside the Tool. `Name` is the Tool's name: WeaponService takes over
-- any Tool with that name (from StarterPack, a shop, ServerStorage.Weapons…),
-- so rename entries to match your existing weapons, or add more.
--
-- Boss HP is balanced against this ladder (Rarities.luau): a Common boss
-- (~5,000 HP) takes a solo starter-weapon player about 10 minutes, while one
-- player with the Reaper's Mythic Blade needs about 70 seconds for a Mythic
-- (~100,000 HP).

local Rarities = require(script.Parent.Rarities)

export type WeaponKind = string -- "Stake" | "Carver" | "Spade" | "Axe" | "Longsword" | "Halberd" | "Greatsword" | "Reaper"

export type WeaponDef = {
	Id: string,
	Name: string, -- Tool name
	Damage: number,
	Cooldown: number, -- seconds between swings
	Range: number, -- studs of reach beyond the boss's body
	Rarity: Rarities.RarityName,
	Starter: boolean?, -- given to every player on spawn
	Kind: WeaponKind, -- procedural look used when no custom model exists
	Glow: Color3?,
	Description: string,
}

local rgb = Color3.fromRGB

local WeaponCatalog = {}

WeaponCatalog.List = {
	{
		Id = "splintered_stake",
		Name = "Splintered Stake",
		Damage = 5,
		Cooldown = 0.6,
		Range = 6,
		Rarity = "Common",
		Starter = true,
		Kind = "Stake",
		Description = "A sharpened fence post. Every hunter starts somewhere.",
	},
	{
		Id = "rusty_pumpkin_carver",
		Name = "Rusty Pumpkin Carver",
		Damage = 15,
		Cooldown = 0.6,
		Range = 6,
		Rarity = "Common",
		Kind = "Carver",
		Glow = rgb(255, 140, 40),
		Description = "Still sticky from last year's harvest.",
	},
	{
		Id = "gravedigger_spade",
		Name = "Gravedigger's Spade",
		Damage = 30,
		Cooldown = 0.65,
		Range = 7,
		Rarity = "Uncommon",
		Kind = "Spade",
		Glow = rgb(104, 196, 118),
		Description = "It has buried a great many things. Some of them twice.",
	},
	{
		Id = "bonecleaver_axe",
		Name = "Bonecleaver Axe",
		Damage = 60,
		Cooldown = 0.7,
		Range = 7,
		Rarity = "Uncommon",
		Kind = "Axe",
		Glow = rgb(170, 220, 120),
		Description = "The haft is a femur. Best not to ask whose.",
	},
	{
		Id = "wraithsteel_longsword",
		Name = "Wraithsteel Longsword",
		Damage = 125,
		Cooldown = 0.65,
		Range = 8,
		Rarity = "Rare",
		Kind = "Longsword",
		Glow = rgb(110, 170, 255),
		Description = "Forged from armor a Wraith Knight left behind.",
	},
	{
		Id = "hexfire_halberd",
		Name = "Hexfire Halberd",
		Damage = 250,
		Cooldown = 0.75,
		Range = 10,
		Rarity = "Epic",
		Kind = "Halberd",
		Glow = rgb(178, 96, 240),
		Description = "Its edge burns with a witch's last curse.",
	},
	{
		Id = "soulrender_greatsword",
		Name = "Soulrender Greatsword",
		Damage = 500,
		Cooldown = 0.8,
		Range = 10,
		Rarity = "Legendary",
		Kind = "Greatsword",
		Glow = rgb(244, 178, 64),
		Description = "Each swing tears a sliver of soul from its target.",
	},
	{
		Id = "reapers_mythic_blade",
		Name = "Reaper's Mythic Blade",
		Damage = 1000,
		Cooldown = 0.7,
		Range = 11,
		Rarity = "Mythic",
		Kind = "Reaper",
		Glow = rgb(236, 54, 76),
		Description = "The Reaper's own blade. Death itself answers when it swings.",
	},
} :: { WeaponDef }

WeaponCatalog.ById = {} :: { [string]: WeaponDef }
WeaponCatalog.ByName = {} :: { [string]: WeaponDef }

local previousDamage = 0
for _, weapon in WeaponCatalog.List do
	assert(WeaponCatalog.ById[weapon.Id] == nil, `Duplicate weapon id "{weapon.Id}"`)
	assert(WeaponCatalog.ByName[weapon.Name] == nil, `Duplicate weapon name "{weapon.Name}"`)
	assert(Rarities.IsValid(weapon.Rarity), `Weapon "{weapon.Id}" has an invalid Rarity`)
	assert(weapon.Damage > 0 and weapon.Cooldown > 0 and weapon.Range > 0, `Weapon "{weapon.Id}" needs positive Damage, Cooldown and Range`)
	-- Starters may share the lowest damage; everything after must be stronger.
	assert(
		weapon.Damage >= previousDamage and (weapon.Starter or weapon.Damage > previousDamage),
		`Weapon "{weapon.Id}" must deal more damage than the weapon before it`
	)
	previousDamage = weapon.Damage
	WeaponCatalog.ById[weapon.Id] = weapon
	WeaponCatalog.ByName[weapon.Name] = weapon
end

function WeaponCatalog.Get(idOrName: string): WeaponDef?
	return WeaponCatalog.ById[idOrName] or WeaponCatalog.ByName[idOrName]
end

return WeaponCatalog
