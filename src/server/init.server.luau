local RunService = game:GetService("RunService")

local InventoryService = require(script.Services.InventoryService)
local BossService = require(script.Bosses.BossService)

InventoryService.Start()
BossService.Start()

if RunService:IsStudio() then
	require(script.Dev.DevTools).Start()
end
