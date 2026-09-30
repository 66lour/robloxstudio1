--!strict
-- Rolls a defeated boss's drops and gives them to everyone who damaged it.
--
-- One set of drops is rolled per kill, and every contributor gets the full set
-- in their saved inventory (players who left before the kill included).
-- Online contributors then get a LootDropped notification.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local ItemCatalog = require(ReplicatedStorage.Shared.Config.ItemCatalog)
local LootRoller = require(ReplicatedStorage.Shared.LootRoller)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BossEffects = require(script.Parent.Parent.Bosses.BossEffects)
local DamageTracker = require(script.Parent.DamageTracker)
local InventoryService = require(script.Parent.InventoryService)

type BossDef = BossRoster.BossDef
type ItemDef = ItemCatalog.ItemDef
type Contributor = DamageTracker.Contributor

-- Players must deal at least this share of the boss's tagged damage to get loot.
-- 0 means any damage counts; raise it (e.g. 0.01) to stop last-second tag-alongs.
local MIN_DAMAGE_SHARE = 0

local LootService = {}

local rng = Random.new()
local lootDropped = Remotes.Get("LootDropped")
local bossAnnouncement = Remotes.Get("BossAnnouncement")

local function describeItem(item: ItemDef)
	return {
		Id = item.Id,
		Name = item.Name,
		Type = item.Type,
		Rarity = item.Rarity,
		Description = item.Description,
		Power = item.Power,
		Exclusive = item.Exclusive,
		Image = item.Image,
	}
end

-- Rolls and distributes loot for one kill. Returns the dropped items.
function LootService.HandleBossDefeat(def: BossDef, contributors: { Contributor }, position: Vector3): { ItemDef }
	local drops = LootRoller.Roll(def, rng)
	local itemIds = table.create(#drops)
	local itemPayload = table.create(#drops)
	for _, item in drops do
		table.insert(itemIds, item.Id)
		table.insert(itemPayload, describeItem(item))
	end

	local rewarded: { Contributor } = {}
	for _, contributor in contributors do
		if contributor.Share >= MIN_DAMAGE_SHARE then
			table.insert(rewarded, contributor)
		end
	end

	for rank, contributor in rewarded do
		task.spawn(function()
			local saved = InventoryService.Grant(contributor.UserId, itemIds, { BossKills = 1 })
			local player = contributor.Player
			if player and player.Parent then
				lootDropped:FireClient(player, {
					BossName = def.Name,
					BossTitle = def.Title,
					BossRarity = def.Rarity,
					Items = itemPayload,
					Damage = math.floor(contributor.Damage),
					Share = contributor.Share,
					Rank = rank,
					Helpers = #rewarded,
					Saved = saved,
				})
			end
			if not saved then
				warn(`[Loot] Failed to save {def.Name} loot for {contributor.Name} ({contributor.UserId})`)
			end
		end)
	end

	local topNames = {}
	for index = 1, math.min(3, #rewarded) do
		table.insert(topNames, rewarded[index].Name)
	end
	bossAnnouncement:FireAllClients({
		Kind = "Defeated",
		BossName = def.Name,
		BossTitle = def.Title,
		BossRarity = def.Rarity,
		TopDamagers = topNames,
		Helpers = #rewarded,
	})

	local names = {}
	for _, item in drops do
		table.insert(names, `{item.Name} [{item.Rarity}]`)
	end
	print(`[Loot] {def.Name} defeated by {#rewarded} player(s); drops: {table.concat(names, ", ")}`)

	BossEffects.LootBurst(position, drops)
	return drops
end

return LootService
