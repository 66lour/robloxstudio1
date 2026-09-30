--!strict
-- Studio-only chat commands for testing the boss system. Not started in live
-- servers.
--
--   !boss [id]       replace the current boss with a new one now (random if no id)
--   !despawn         remove the current boss (no loot); the 20-minute timer restarts
--   !timer [seconds] set the portal countdown (default 10)
--   !plot            toggle your "Plot" attribute: bosses only fight players with a plot
--   !weapon <id|all> give yourself a weapon from WeaponCatalog (e.g. !weapon reapers_mythic_blade)
--   !bosses          list boss ids

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponCatalog = require(ReplicatedStorage.Shared.Config.WeaponCatalog)
local BossService = require(script.Parent.Parent.Bosses.BossService)
local BossSpawnCycle = require(script.Parent.Parent.Bosses.BossSpawnCycle)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local WeaponService = require(script.Parent.Parent.Weapons.WeaponService)

local DevTools = {}

local notice = Remotes.Get("Notice")

local function tell(player: Player, text: string)
	print(`[DevTools] {text}`)
	notice:FireClient(player, { Text = text })
end

local function bossIds(): string
	local ids = {}
	for _, def in BossRoster.List do
		table.insert(ids, def.Id)
	end
	return table.concat(ids, ", ")
end

local COMMANDS: { [string]: (player: Player, argument: string) -> () } = {}

function COMMANDS.boss(player, argument)
	if argument ~= "" and not BossRoster.Get(argument) then
		tell(player, `Unknown boss "{argument}". Ids: {bossIds()}`)
		return
	end
	local model = BossSpawnCycle.SpawnNow(if argument ~= "" then argument else nil)
	tell(player, if model then `Spawned {model.Name} at the Dark Portal` else "Boss spawn failed (see output)")
end

function COMMANDS.despawn(player)
	if BossService.GetActive() then
		BossService.Despawn()
		tell(player, "Boss removed; the portal countdown restarted")
	else
		tell(player, "No boss is alive")
	end
end

function COMMANDS.timer(player, argument)
	local seconds = tonumber(argument) or 10
	if BossService.GetActive() then
		tell(player, "A boss is alive; the timer only runs while the map has no boss")
		return
	end
	BossSpawnCycle.ResetTimer(seconds)
	tell(player, `Next boss in {seconds} s`)
end

function COMMANDS.plot(player)
	local assigned = PlotService.IsAssigned(player)
	player:SetAttribute("Plot", if assigned then "Not Assigned" else "Studio Test Plot")
	-- The assignment is cached briefly; report the value we just set.
	tell(player, if assigned then "You are now a guest: bosses ignore you and you can't hurt them" else "You now own a (test) plot: bosses will hunt you")
end

function COMMANDS.weapon(player, argument)
	if argument == "all" then
		for _, def in WeaponCatalog.List do
			WeaponService.Give(player, def.Id)
		end
		tell(player, "Gave every weapon")
		return
	end
	local def = WeaponCatalog.Get(argument)
	if not def then
		local ids = {}
		for _, weapon in WeaponCatalog.List do
			table.insert(ids, `{weapon.Id} ({weapon.Damage})`)
		end
		tell(player, `Unknown weapon. Ids: {table.concat(ids, ", ")}`)
		return
	end
	WeaponService.Give(player, def.Id)
	tell(player, `Gave {def.Name}`)
end

function COMMANDS.bosses(player)
	tell(player, `Boss ids: {bossIds()}`)
end

local function onChatted(player: Player, message: string)
	local command, match = string.match(message, "^!(%w+)%s*(.-)%s*$")
	if not command then
		return
	end
	local handler = COMMANDS[string.lower(command)]
	if handler then
		handler(player, match or "")
	end
end

function DevTools.Start()
	local function onPlayer(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	print("[DevTools] Studio commands: !boss [id], !despawn, !timer [seconds], !plot, !weapon <id|all>, !bosses")
end

return DevTools
