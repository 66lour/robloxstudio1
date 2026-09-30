-- Server entry point. Starts every service; the boss spawn cycle (one boss per
-- map, emerging from the Dark Portal every 20 minutes) lives in
-- Bosses/BossSpawnCycle.
local RunService = game:GetService("RunService")

local PlotService = require(script.Services.PlotService)
local InventoryService = require(script.Services.InventoryService)
local BossService = require(script.Bosses.BossService)
local BossSpawnCycle = require(script.Bosses.BossSpawnCycle)
local WeaponService = require(script.Weapons.WeaponService)

PlotService.Start()
InventoryService.Start()
BossService.Start()
BossSpawnCycle.Start()
WeaponService.Start()

if RunService:IsStudio() then
	require(script.Dev.DevTools).Start()
end
