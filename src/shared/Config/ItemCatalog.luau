--!strict
-- Every collectible (Pet or Armor) that bosses can drop.
--
-- "Pool" items can drop from any boss, depending on the loot rarity roll.
-- "Exclusive" items drop only from the boss named in `Source` (see BossRoster).
-- Item ids are stored in player DataStores, so never rename an existing id.

local Rarities = require(script.Parent.Rarities)

type RarityName = Rarities.RarityName

export type ItemType = string -- "Pet" or "Armor"

export type ItemDef = {
	Id: string,
	Name: string,
	Type: ItemType,
	Rarity: RarityName,
	Description: string,
	-- Strength stat shown in the UI, for an equip system to use. The boss
	-- system doesn't apply it.
	Power: number,
	Exclusive: boolean,
	Source: string?, -- boss id for exclusive drops
	Image: string?, -- optional rbxassetid:// icon; the UI falls back to a glyph
}

local ItemCatalog = {}

-- Base Power per rarity, used when an item doesn't set its own.
local POWER_BY_RANK = { 5, 10, 18, 30, 50, 80 }

local definitions: { any } = {
	-- ── Common ────────────────────────────────────────────────────────────
	{ Id = "pet_bone_rat", Name = "Bone Rat", Type = "Pet", Rarity = "Common", Description = "It rattles when it's happy." },
	{ Id = "pet_grave_moth", Name = "Grave Moth", Type = "Pet", Rarity = "Common", Description = "Drawn to candlelight and to the recently departed." },
	{ Id = "armor_tattered_hood", Name = "Tattered Gravedigger Hood", Type = "Armor", Rarity = "Common", Description = "Smells faintly of wet soil." },
	{ Id = "armor_rusted_mail", Name = "Rusted Chain Vest", Type = "Armor", Rarity = "Common", Description = "More rust than chain, but it stops a blade." },

	-- ── Uncommon ──────────────────────────────────────────────────────────
	{ Id = "pet_ember_imp", Name = "Ember Imp", Type = "Pet", Rarity = "Uncommon", Description = "Mischievous and warm, like a live coal." },
	{ Id = "pet_bog_toad", Name = "Bog Toad", Type = "Pet", Rarity = "Uncommon", Description = "Croaks in a language nobody alive remembers." },
	{ Id = "armor_gravewarden_greaves", Name = "Gravewarden Greaves", Type = "Armor", Rarity = "Uncommon", Description = "Worn by those who keep the dead in the ground." },
	{ Id = "armor_hexweave_cloak", Name = "Hexweave Cloak", Type = "Armor", Rarity = "Uncommon", Description = "Its threads twist away from hostile magic." },

	-- ── Rare ──────────────────────────────────────────────────────────────
	{ Id = "pet_spectral_hound", Name = "Spectral Hound", Type = "Pet", Rarity = "Rare", Description = "A loyal hound that died guarding its master." },
	{ Id = "pet_crypt_bat", Name = "Crypt Bat Matriarch", Type = "Pet", Rarity = "Rare", Description = "Its screech can crack tombstones." },
	{ Id = "armor_bloodiron_cuirass", Name = "Bloodiron Cuirass", Type = "Armor", Rarity = "Rare", Description = "Forged in a quench of something that wasn't water." },
	{ Id = "armor_moonsilver_helm", Name = "Moonsilver Helm", Type = "Armor", Rarity = "Rare", Description = "Cold to the touch, even in the sun." },

	-- ── Epic ──────────────────────────────────────────────────────────────
	{ Id = "pet_nightmare_foal", Name = "Nightmare Foal", Type = "Pet", Rarity = "Epic", Description = "Its hooves leave smouldering prints." },
	{ Id = "pet_ashen_wyrmling", Name = "Ashen Wyrmling", Type = "Pet", Rarity = "Epic", Description = "A young dragon born from a funeral pyre." },
	{ Id = "armor_duskforged_plate", Name = "Duskforged Plate", Type = "Armor", Rarity = "Epic", Description = "Hammered only in the hour between day and night." },
	{ Id = "armor_veil_of_whispers", Name = "Veil of Whispers", Type = "Armor", Rarity = "Epic", Description = "The voices woven into it warn you of blows." },

	-- ── Legendary ─────────────────────────────────────────────────────────
	{ Id = "pet_obsidian_gryphon", Name = "Obsidian Gryphon", Type = "Pet", Rarity = "Legendary", Description = "Carved by a mad sculptor, woken by a madder god." },
	{ Id = "pet_soulflame_phoenix", Name = "Soulflame Phoenix", Type = "Pet", Rarity = "Legendary", Description = "Rises from the ashes of the souls it guards." },
	{ Id = "armor_hollow_crown", Name = "Crown of the Hollow King", Type = "Armor", Rarity = "Legendary", Description = "Whoever wears it hears the old kingdom kneel." },
	{ Id = "armor_eclipse_aegis", Name = "Aegis of the Eclipse", Type = "Armor", Rarity = "Legendary", Description = "A shield of black sunlight." },

	-- ── Mythic ────────────────────────────────────────────────────────────
	{ Id = "pet_void_leviathan", Name = "Void Leviathan Hatchling", Type = "Pet", Rarity = "Mythic", Description = "Small for now. It swims through the spaces between stars." },
	{ Id = "pet_eldritch_seraph", Name = "Eldritch Seraph", Type = "Pet", Rarity = "Mythic", Description = "Too many wings. Far too many eyes." },
	{ Id = "armor_last_star_mantle", Name = "Mantle of the Last Star", Type = "Armor", Rarity = "Mythic", Description = "Woven from the final light of a dying sky." },
	{ Id = "armor_godslayer_regalia", Name = "Godslayer Regalia", Type = "Armor", Rarity = "Mythic", Description = "Its last owner was worshipped. Briefly." },

	-- ── Boss exclusives (one per boss, same rarity as the boss) ───────────
	{ Id = "armor_skeleton_ribcage", Name = "Cursed Ribcage Guard", Type = "Armor", Rarity = "Common", Source = "cursed_skeleton", Description = "Still twitches when a skeleton walks by." },
	{ Id = "pet_ghoul_maggot", Name = "Gorged Grave Maggot", Type = "Pet", Rarity = "Common", Source = "rotting_ghoul", Description = "Fat, cheerful and extremely loyal." },
	{ Id = "pet_swamp_wisp", Name = "Mirewisp", Type = "Pet", Rarity = "Common", Source = "bog_hag", Description = "A wisp that leads travellers into the marsh. Now it leads you." },
	{ Id = "armor_wraith_visor", Name = "Wraithsteel Visor", Type = "Armor", Rarity = "Uncommon", Source = "wraith_knight", Description = "Through its slits you can see the dead." },
	{ Id = "pet_plague_ratling", Name = "Plague Ratling", Type = "Pet", Rarity = "Uncommon", Source = "plague_rat_king", Description = "Heir to a throne of tails." },
	{ Id = "armor_tombstone_pauldrons", Name = "Tombstone Pauldrons", Type = "Armor", Rarity = "Uncommon", Source = "gravebound_golem", Description = "The engraved names are still legible." },
	{ Id = "pet_jack_o_wisp", Name = "Jack-o'-Wisp", Type = "Pet", Rarity = "Rare", Source = "pumpkin_lord", Description = "A grinning pumpkin spirit with a candle for a heart." },
	{ Id = "armor_bloodmoon_pelt", Name = "Bloodmoon Pelt", Type = "Armor", Rarity = "Rare", Source = "bloodmoon_werewolf", Description = "It bristles when the moon turns red." },
	{ Id = "pet_phylactery_familiar", Name = "Phylactery Familiar", Type = "Pet", Rarity = "Rare", Source = "crypt_lich", Description = "A floating shard of the lich's soul, grudgingly obedient." },
	{ Id = "armor_banshee_shroud", Name = "Shroud of the Keening Bride", Type = "Armor", Rarity = "Epic", Source = "frostbound_banshee", Description = "Frost spreads from its hem wherever you walk." },
	{ Id = "pet_abyssal_eye", Name = "Abyssal Watcher", Type = "Pet", Rarity = "Epic", Source = "abyssal_warden", Description = "An eye that has seen the bottom of the abyss and kept looking." },
	{ Id = "armor_colossus_heart", Name = "Molten Colossus Heartplate", Type = "Armor", Rarity = "Legendary", Source = "infernal_colossus", Description = "It still beats. Slowly." },
	{ Id = "pet_fallen_cherub", Name = "Fallen Eclipse Cherub", Type = "Pet", Rarity = "Legendary", Source = "eclipse_seraph", Description = "A small angel that chose the dark side of the sun." },
	{ Id = "pet_starving_void", Name = "Nyx'thal Spawnling", Type = "Pet", Rarity = "Mythic", Source = "nyxthal", Description = "It is always hungry. It has already eaten a moon." },
	{ Id = "armor_pale_king_raiment", Name = "Raiment of the Pale King", Type = "Armor", Rarity = "Mythic", Source = "pale_king", Description = "The crown of a kingdom that exists only in dreams." },
}

ItemCatalog.Items = {} :: { [string]: ItemDef }
-- Pool (non-exclusive) items grouped by rarity, then by type: Pool[rarity][type] = { ItemDef }
ItemCatalog.Pool = {} :: { [RarityName]: { [ItemType]: { ItemDef } } }
-- Exclusive items grouped by source boss id.
ItemCatalog.ExclusivesBySource = {} :: { [string]: { ItemDef } }

for _, rarityName in Rarities.Order do
	ItemCatalog.Pool[rarityName] = { Pet = {}, Armor = {} }
end

for _, raw in definitions do
	assert(type(raw.Id) == "string" and raw.Id ~= "", "Item is missing an Id")
	assert(ItemCatalog.Items[raw.Id] == nil, `Duplicate item id "{raw.Id}"`)
	assert(raw.Type == "Pet" or raw.Type == "Armor", `Item "{raw.Id}" has an invalid Type`)
	assert(Rarities.IsValid(raw.Rarity), `Item "{raw.Id}" has an invalid Rarity`)

	local rank = Rarities.Rank(raw.Rarity)
	local item: ItemDef = {
		Id = raw.Id,
		Name = raw.Name,
		Type = raw.Type,
		Rarity = raw.Rarity,
		Description = raw.Description or "",
		-- Exclusives are a little stronger than pool items of the same rarity.
		Power = raw.Power or math.floor(POWER_BY_RANK[rank] * (if raw.Source then 1.25 else 1)),
		Exclusive = raw.Source ~= nil,
		Source = raw.Source,
		Image = raw.Image,
	}
	ItemCatalog.Items[item.Id] = item

	if item.Source then
		local list = ItemCatalog.ExclusivesBySource[item.Source]
		if not list then
			list = {}
			ItemCatalog.ExclusivesBySource[item.Source] = list
		end
		table.insert(list, item)
	else
		table.insert(ItemCatalog.Pool[item.Rarity][item.Type], item)
	end
end

-- The loot roller needs at least one pool item of each type in every tier.
for _, rarityName in Rarities.Order do
	for _, itemType in { "Pet", "Armor" } do
		assert(#ItemCatalog.Pool[rarityName][itemType] > 0, `No pool {itemType} items for rarity {rarityName}`)
	end
end

function ItemCatalog.Get(id: string): ItemDef?
	return ItemCatalog.Items[id]
end

return ItemCatalog
