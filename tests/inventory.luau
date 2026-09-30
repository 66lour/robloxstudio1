-- InventoryService against a mock DataStore.
-- Run from the repo root with Lune: lune run tests/inventory
local process = require("@lune/process")
local task = require("@lune/task")
local Harness = require("./harness")

-- Mocks ----------------------------------------------------------------------

local function Signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				task.spawn(fn, ...)
			end
		end,
	}
end

local store = { data = {}, loadDelay = 0, failLoads = {}, updates = 0 }
function store:GetAsync(key)
	task.wait(self.loadDelay)
	if self.failLoads[key] then
		error("mock outage")
	end
	local value = self.data[key]
	-- Return a copy, like a real DataStore.
	return if value then Harness.deepCopy(value) else nil
end
function store:UpdateAsync(key, transform)
	self.updates += 1
	local result = transform(if self.data[key] then Harness.deepCopy(self.data[key]) else nil)
	if result ~= nil then
		self.data[key] = Harness.deepCopy(result)
	end
	return result
end

local Players = { PlayerAdded = Signal(), PlayerRemoving = Signal(), list = {} }
function Players:GetPlayers()
	local result = {}
	for _, p in self.list do
		table.insert(result, p)
	end
	return result
end
function Players:GetPlayerByUserId(userId)
	return self.list[userId]
end

local snapshots = {}
local services = {
	Players = Players,
	DataStoreService = {
		GetDataStore = function()
			return store
		end,
	},
	RunService = {
		IsStudio = function()
			return false
		end,
		IsServer = function()
			return true
		end,
	},
	ReplicatedStorage = { Shared = Harness.shared() },
}
local game = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
	BindToClose = function() end,
}

Harness.override("src/shared/Remotes.luau", {
	Get = function()
		return {
			FireClient = function(_, player, items)
				snapshots[player.UserId] = items
			end,
		}
	end,
})
Harness.setGlobals({
	game = game,
	task = task,
	warn = function() end,
})

local InventoryService = Harness.require(Harness.server().Services.InventoryService)
InventoryService.Start()

local function join(userId)
	local player = { UserId = userId, Name = "Player" .. userId, Parent = Players }
	Players.list[userId] = player
	Players.PlayerAdded:Fire(player)
	return player
end
local function leave(player)
	Players.list[player.UserId] = nil
	player.Parent = nil
	Players.PlayerRemoving:Fire(player)
end

local failures = 0
local function check(condition, message)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- 1. Online grant lands in the session and is saved on leave.
local alice = join(1)
task.wait(0.05)
check(InventoryService.IsLoaded(alice), "alice should be loaded")
check(InventoryService.Grant(1, { "pet_bone_rat", "pet_bone_rat", "armor_rusted_mail" }, { BossKills = 1 }), "online grant")
check(InventoryService.GetItems(alice).pet_bone_rat == 2, "alice should have 2 bone rats")
check(snapshots[1] and snapshots[1].pet_bone_rat == 2, "alice's client should get a snapshot")
leave(alice)
task.wait(0.05)
check(store.data.Player_1 and store.data.Player_1.Items.pet_bone_rat == 2, "alice's items saved on leave")
check(store.data.Player_1.Stats.BossKills == 1, "alice's BossKills saved")

-- 2. Rejoin loads saved data.
alice = join(1)
task.wait(0.05)
check(InventoryService.GetItems(alice).armor_rusted_mail == 1, "alice's data loads on rejoin")

-- 3. Grants while loading are queued and merged.
store.loadDelay = 0.2
local bob = join(2)
task.wait(0.02)
check(not InventoryService.IsLoaded(bob), "bob should still be loading")
check(InventoryService.Grant(2, { "pet_ember_imp" }), "grant during load")
task.wait(0.3)
check(InventoryService.GetItems(bob).pet_ember_imp == 1, "queued grant merged after load")
store.loadDelay = 0

-- 4. Offline player (never joined this server) gets the grant written directly.
store.data.Player_3 = { Version = 1, Items = { pet_grave_moth = 4 }, Stats = { BossKills = 7 } }
check(InventoryService.Grant(3, { "pet_grave_moth" }, { BossKills = 1 }), "offline grant")
check(store.data.Player_3.Items.pet_grave_moth == 5, "offline grant keeps existing items")
check(store.data.Player_3.Stats.BossKills == 8, "offline grant bumps stats")

-- 5. Failed load: session is never saved (can't overwrite real data), grants go straight to the store.
store.data.Player_4 = { Version = 1, Items = { pet_void_leviathan = 1 }, Stats = {} }
store.failLoads.Player_4 = true
local carol = join(4)
-- The service retries with 1 + 2 + 4 + 8 s backoff before giving up.
task.wait(15.5)
check(not InventoryService.IsLoaded(carol), "carol's load should have failed")
check(InventoryService.Grant(4, { "armor_hollow_crown" }), "grant after failed load")
check(store.data.Player_4.Items.armor_hollow_crown == 1, "grant after failed load written to store")
check(store.data.Player_4.Items.pet_void_leviathan == 1, "existing data untouched after failed load")
local before = store.updates
leave(carol)
task.wait(0.05)
check(store.updates == before, "a failed-load session must not be saved")

-- 6. Grant arriving while a player is leaving still ends up saved.
local dave = join(5)
task.wait(0.05)
leave(dave)
InventoryService.Grant(5, { "pet_nightmare_foal" })
task.wait(0.1)
check(store.data.Player_5 and store.data.Player_5.Items.pet_nightmare_foal == 1, "grant during leave saved")

print("")
if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("All inventory checks passed")
-- The autosave loop never ends on its own.
process.exit(0)
