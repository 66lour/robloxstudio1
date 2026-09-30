--!strict
-- Boss spawn cycle, hunting and combat tuning. Per-boss stats live in
-- ReplicatedStorage.Shared.Config.BossRoster.

return {
	-- Spawn cycle: only ONE boss exists in the map at a time. When it is
	-- defeated, the next one emerges from the Dark Portal SpawnInterval seconds
	-- later.
	SpawnInterval = 1200, -- 20 minutes
	FirstSpawnDelay = 1200, -- countdown after the server starts
	-- A boss that disappears without being defeated (fell out of the world) is
	-- replaced after this many seconds instead.
	LostBossRespawnDelay = 15,

	-- The Dark Portal: the first Workspace descendant with one of these names
	-- (a Part or a Model). Put an Attachment named "BossSpawn" inside it to pick
	-- the exact spawn spot; otherwise bosses emerge in front of it (its
	-- LookVector side). Without a portal in the map, a placeholder is built at
	-- PlaceholderPortalPosition so everything still works.
	PortalNames = { "DarkPortal", "Dark Portal" },
	PortalSpawnDistance = 10,
	PlaceholderPortalPosition = Vector3.new(0, 0, -120),
	ShowPortalCountdown = true,

	-- Optional custom boss models: a Model named after the boss id (e.g.
	-- "pumpkin_lord") inside ServerStorage.BossModels.
	CustomModelFolderName = "BossModels",

	-- Hunting: bosses chase assigned players anywhere within HuntRange and
	-- never give up while the target stays valid. Guests and players inside
	-- their own tycoon are ignored (PlotService).
	HuntRange = 600,
	-- The current target keeps priority unless someone else is this much closer (fraction).
	Stickiness = 0.25,
	-- Players who hit the boss in the last 8 seconds count as this many studs closer.
	RecentAttackerBonus = 30,
	-- Safety net: a boss further than this from the portal is teleported back.
	MaxDistanceFromPortal = 3000,
	-- Walk around obstacles with PathfindingService when the straight line is blocked.
	Pathfinding = true,

	-- AI
	ThinkInterval = 0.2,
	MeleeReach = 5, -- studs, plus 2 per point of boss scale
	MeleeWindup = 0.45,
	EmergeDuration = 2.2, -- seconds the boss spends climbing out of the portal

	-- With no target for this long, the boss walks home and regenerates; once
	-- fully healed its damage tags reset.
	IdleRegenDelay = 30,
	IdleRegenRate = 0.03, -- share of max health per second

	-- Death
	CorpseDuration = 4, -- seconds the death animation/dissolve plays

	-- Guests (no plot) can't be hurt by bosses. With this false they can't
	-- damage bosses either, so nobody earns loot while invulnerable.
	GuestsCanDamageBosses = false,
}
