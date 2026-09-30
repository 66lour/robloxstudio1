--!strict
-- DataStore-backed player inventory (collectible Pets and Armors).
--
-- Stored per player under "Player_<UserId>" in the "PlayerInventory_v1" store:
--   { Version = 1, Items = { [itemId] = count }, Stats = { BossKills = n } }
--
-- Grant() works whether or not the player is in this server:
--   * session loaded       -> added to the session, saved by autosave/leave
--   * session still loading-> queued and merged once the load finishes
--   * player gone / load failed -> written straight to the DataStore with UpdateAsync
-- so a player who left mid-fight still receives their share of the loot.
--
-- In Studio without "Enable Studio Access to API Services" the service falls
-- back to in-memory data (nothing is saved) and says so in the output.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemCatalog = require(ReplicatedStorage.Shared.Config.ItemCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STORE_NAME = "PlayerInventory_v1"
local KEY_PREFIX = "Player_"
local DATA_VERSION = 1
local AUTOSAVE_INTERVAL = 120
local MAX_ATTEMPTS = 5
local SHUTDOWN_TIMEOUT = 25

export type InventoryData = {
	Version: number,
	Items: { [string]: number },
	Stats: { [string]: number },
}

type Grant = { Items: { string }, Stats: { [string]: number }? }

type Session = {
	Player: Player,
	Data: InventoryData,
	Loading: boolean,
	Loaded: boolean, -- false after a failed load: the session is never saved
	Dirty: boolean,
	Saving: boolean,
	Pending: { Grant },
}

local InventoryService = {}

local store: DataStore? = nil
local sessions: { [Player]: Session } = {}
local inventoryUpdated = Remotes.Get("InventoryUpdated")

local function keyFor(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

local function defaultData(): InventoryData
	return {
		Version = DATA_VERSION,
		Items = {},
		Stats = { BossKills = 0 },
	}
end

-- Turns whatever is stored (or nil) into valid InventoryData. Items that are no
-- longer in the catalog are kept so a catalog mistake can't wipe them.
local function reconcile(raw: any): InventoryData
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.Items) == "table" then
		for id, count in raw.Items do
			if type(id) == "string" and type(count) == "number" and count > 0 then
				data.Items[id] = math.floor(count)
			end
		end
	end
	if type(raw.Stats) == "table" then
		for name, value in raw.Stats do
			if type(name) == "string" and type(value) == "number" then
				data.Stats[name] = value
			end
		end
	end
	return data
end

local function applyGrant(data: InventoryData, grant: Grant)
	for _, itemId in grant.Items do
		data.Items[itemId] = (data.Items[itemId] or 0) + 1
	end
	if grant.Stats then
		for name, delta in grant.Stats do
			data.Stats[name] = (data.Stats[name] or 0) + delta
		end
	end
end

local function retry(label: string, callback: () -> any): (boolean, any)
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		warn(`[Inventory] {label} failed (attempt {attempt}/{MAX_ATTEMPTS}): {result}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, nil
end

local function sendSnapshot(session: Session)
	if session.Player.Parent then
		inventoryUpdated:FireClient(session.Player, session.Data.Items, session.Data.Stats)
	end
end

-- Writes a grant straight to the DataStore for a player who has no usable
-- session in this server.
local function grantOffline(userId: number, grant: Grant): boolean
	local activeStore = store
	if not activeStore then
		warn(`[Inventory] No DataStore access; dropped offline grant for user {userId}`)
		return false
	end
	local ok = retry(`offline grant for {userId}`, function()
		return activeStore:UpdateAsync(keyFor(userId), function(old)
			local data = reconcile(old)
			applyGrant(data, grant)
			return data
		end)
	end)
	return ok
end

local function saveSession(session: Session): boolean
	local activeStore = store
	if not activeStore or not session.Loaded then
		return true
	end
	if session.Saving then
		-- Another save is running; it re-checks Dirty when it finishes.
		return true
	end
	session.Saving = true
	local ok = true
	while session.Dirty do
		session.Dirty = false
		local snapshot = table.clone(session.Data)
		snapshot.Items = table.clone(session.Data.Items)
		snapshot.Stats = table.clone(session.Data.Stats)
		ok = retry(`save for {session.Player.UserId}`, function()
			return activeStore:UpdateAsync(keyFor(session.Player.UserId), function()
				return snapshot
			end)
		end)
		if not ok then
			session.Dirty = true
			break
		end
	end
	session.Saving = false
	return ok
end

local function flushPendingOffline(session: Session)
	local pending = session.Pending
	session.Pending = {}
	for _, grant in pending do
		grantOffline(session.Player.UserId, grant)
	end
end

local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local session: Session = {
		Player = player,
		Data = defaultData(),
		Loading = true,
		Loaded = false,
		Dirty = false,
		Saving = false,
		Pending = {},
	}
	sessions[player] = session

	local activeStore = store
	local ok, raw
	if activeStore then
		ok, raw = retry(`load for {player.UserId}`, function()
			return activeStore:GetAsync(keyFor(player.UserId))
		end)
	else
		ok, raw = true, nil
	end
	session.Loading = false

	if not ok then
		warn(`[Inventory] Could not load data for {player.Name}; this session will not be saved`)
		flushPendingOffline(session)
		if player.Parent == nil then
			sessions[player] = nil
		else
			sendSnapshot(session)
		end
		return
	end

	session.Data = reconcile(raw)
	session.Loaded = true

	if player.Parent == nil then
		-- Left while loading: nothing to save except queued grants.
		sessions[player] = nil
		flushPendingOffline(session)
		return
	end

	if #session.Pending > 0 then
		for _, grant in session.Pending do
			applyGrant(session.Data, grant)
		end
		session.Pending = {}
		session.Dirty = true
	end
	sendSnapshot(session)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session or session.Loading then
		-- onPlayerAdded notices the player left once the load finishes.
		return
	end
	-- Keep the session registered while saving so grants arriving now still land
	-- in it (saveSession loops until it is no longer dirty).
	saveSession(session)
	sessions[player] = nil
end

-- Detects Studio sessions that can't reach DataStores.
local function openStore(): DataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warn(`[Inventory] DataStores unavailable ({result}); using in-memory inventories`)
		return nil
	end
	local dataStore = result :: DataStore
	if RunService:IsStudio() then
		local probeOk, probeError = pcall(function()
			return dataStore:GetAsync("__studio_probe")
		end)
		if not probeOk then
			warn(`[Inventory] DataStores unavailable in Studio ({probeError}). Enable "Studio Access to API Services" to test saving; using in-memory inventories`)
			return nil
		end
	end
	return dataStore
end

function InventoryService.Start()
	store = openStore()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, session in sessions do
				if session.Dirty then
					task.spawn(saveSession, session)
				end
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for _, session in sessions do
			if session.Loaded and session.Dirty then
				remaining += 1
				task.spawn(function()
					saveSession(session)
					remaining -= 1
				end)
			end
		end
		local deadline = os.clock() + SHUTDOWN_TIMEOUT
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Grants items (by id, one per entry) and optional stat increments to a user.
-- Works for players in this server, players still loading, and players who
-- already left. Returns false only if the grant could not be recorded.
function InventoryService.Grant(userId: number, itemIds: { string }, stats: { [string]: number }?): boolean
	for _, itemId in itemIds do
		assert(ItemCatalog.Get(itemId), `Unknown item id "{itemId}"`)
	end
	local grant: Grant = { Items = itemIds, Stats = stats }

	local player = Players:GetPlayerByUserId(userId)
	local session = if player then sessions[player] else nil
	if session then
		if session.Loading then
			table.insert(session.Pending, grant)
			return true
		elseif session.Loaded then
			applyGrant(session.Data, grant)
			session.Dirty = true
			sendSnapshot(session)
			if session.Player.Parent == nil then
				-- Player is leaving and the final save may already be done.
				task.spawn(saveSession, session)
			end
			return true
		end
	end
	return grantOffline(userId, grant)
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number?): boolean
	local ids = table.create(amount or 1, itemId)
	return InventoryService.Grant(player.UserId, ids)
end

function InventoryService.IsLoaded(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.Loaded
end

-- Returns a copy of the player's items ({ [itemId] = count }), or nil if not loaded.
function InventoryService.GetItems(player: Player): { [string]: number }?
	local session = sessions[player]
	if not session or not session.Loaded then
		return nil
	end
	return table.clone(session.Data.Items)
end

function InventoryService.GetStat(player: Player, name: string): number
	local session = sessions[player]
	return if session then session.Data.Stats[name] or 0 else 0
end

return InventoryService
