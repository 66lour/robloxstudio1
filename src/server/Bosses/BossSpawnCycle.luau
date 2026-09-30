--!strict
-- The boss spawn cycle: ONE boss per map, emerging from the Dark Portal.
--
--   * When the server starts, the portal counts down FirstSpawnDelay seconds.
--   * At zero a boss is rolled (by rarity weight) and emerges from the portal.
--   * While it lives no other boss can spawn and the countdown is paused.
--   * The moment it is defeated the countdown restarts at SpawnInterval
--     (1200 s = 20 minutes).
-- The time left is on the portal's billboard and in the workspace attribute
-- "NextBossSpawnAt" (server time, for your own UI).

local Workspace = game:GetService("Workspace")

local BossService = require(script.Parent.BossService)
local BossSettings = require(script.Parent.BossSettings)
local DarkPortal = require(script.Parent.DarkPortal)

local BossSpawnCycle = {}

local nextSpawnAt: number? = nil -- os.clock() time; nil while a boss is alive
local started = false

local function setTimer(seconds: number)
	nextSpawnAt = os.clock() + seconds
	Workspace:SetAttribute("NextBossSpawnAt", Workspace:GetServerTimeNow() + seconds)
end

local function spawnNow(bossId: string?): Model?
	DarkPortal.Burst()
	local model = BossService.Spawn(bossId, DarkPortal.GetSpawnCFrame())
	if model then
		nextSpawnAt = nil
		Workspace:SetAttribute("NextBossSpawnAt", nil)
	end
	return model
end

-- Seconds until the next boss, or nil while one is alive.
function BossSpawnCycle.GetTimeRemaining(): number?
	if not nextSpawnAt then
		return nil
	end
	return math.max(0, nextSpawnAt - os.clock())
end

-- Restarts the countdown (default: a full SpawnInterval). Ignored while a boss lives.
function BossSpawnCycle.ResetTimer(seconds: number?)
	if BossService.GetActive() then
		return
	end
	setTimer(seconds or BossSettings.SpawnInterval)
end

-- Replaces the current boss (if any) with a new one right now (admin/testing).
function BossSpawnCycle.SpawnNow(bossId: string?): Model?
	if BossService.GetActive() then
		BossService.Despawn("Replaced")
	end
	return spawnNow(bossId)
end

function BossSpawnCycle.Start()
	if started then
		return
	end
	started = true
	DarkPortal.Setup()

	BossService.Removed:Connect(function(_def, reason: string)
		if reason == "Replaced" then
			return
		end
		setTimer(if reason == "Lost" then BossSettings.LostBossRespawnDelay else BossSettings.SpawnInterval)
	end)

	setTimer(BossSettings.FirstSpawnDelay)
	task.spawn(function()
		while true do
			local active = BossService.GetActive()
			if active then
				DarkPortal.SetStatus(active.Def.Name, nil)
			else
				local remaining = BossSpawnCycle.GetTimeRemaining()
				if not remaining then
					setTimer(BossSettings.SpawnInterval)
					remaining = BossSettings.SpawnInterval
				end
				DarkPortal.SetStatus(nil, remaining)
				if (remaining :: number) <= 0 then
					local ok, result = pcall(spawnNow, nil)
					if not ok or not result then
						warn(`[Bosses] Boss spawn failed: {if ok then "refused" else result}; retrying in 10 s`)
						setTimer(10)
					end
				end
			end
			task.wait(1)
		end
	end)
	print(`[Bosses] Spawn cycle started: first boss in {BossSettings.FirstSpawnDelay} s, then {BossSettings.SpawnInterval} s after each defeat.`)
end

return BossSpawnCycle
