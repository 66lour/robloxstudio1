--!strict
-- Creates (on the server) or finds (on the client) the game's RemoteEvents.
--
--   LootDropped       server -> client  a player received boss loot
--   BossAnnouncement  server -> clients a boss spawned or was defeated
--   InventoryUpdated  server -> client  full inventory snapshot after a change
--   Notice            server -> client  short message (e.g. "claim a plot first")
--   DamageDealt       server -> client  your hit landed: show a damage number

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENT_NAMES = { "LootDropped", "BossAnnouncement", "InventoryUpdated", "Notice", "DamageDealt" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	assert(table.find(EVENT_NAMES, name), `Unknown remote "{name}"`)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
