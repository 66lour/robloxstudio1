--!strict
-- Spawner and AI tuning. Per-boss stats live in ReplicatedStorage.Shared.Config.BossRoster.

return {
	-- Spawning
	MaxActiveBosses = 3,
	FirstSpawnDelay = 5, -- seconds after server start
	SpawnInterval = 45, -- seconds between spawn attempts while below the cap
	-- Parts inside a Workspace folder with this name are used as spawn points.
	-- Without one, bosses spawn in a ring around the world origin.
	SpawnFolderName = "BossSpawns",
	FallbackSpawnRadius = 60,

	-- Optional custom models: put a Model named after a boss id (e.g.
	-- "pumpkin_lord") in ServerStorage.BossModels. It needs a Humanoid and a
	-- PrimaryPart (HumanoidRootPart). It is scaled with Model:ScaleTo(). Bosses
	-- without one get a procedurally built model.
	CustomModelFolderName = "BossModels",

	-- AI
	ThinkInterval = 0.2,
	AggroRange = 80, -- studs, plus 6 per point of boss scale
	LeashRange = 140, -- bosses return to their spawn if pulled further than this
	MeleeReach = 5, -- studs, plus 2 per point of boss scale
	MeleeWindup = 0.35,

	-- Death
	CorpseDuration = 3, -- seconds the dissolve effect plays before cleanup
}
