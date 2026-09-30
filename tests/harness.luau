-- Loads Rojo-style ModuleScripts (which use `script.Parent.X`) outside Roblox.
-- Run with Lune from the repo root: lune run tests/run
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- Minimal Random compatible with Roblox's API (deterministic per seed).
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	local self = setmetatable({ state = (seed or os.clock() * 1e6) % 2147483647 }, Random)
	if self.state <= 0 then
		self.state += 2147483646
	end
	return self
end
function Random:NextNumber(min: number?, max: number?)
	self.state = (self.state * 48271) % 2147483647
	local unit = (self.state - 1) / 2147483646
	if min and max then
		return min + unit * (max - min)
	end
	return unit
end
function Random:NextInteger(min: number, max: number)
	return math.min(max, min + math.floor(self:NextNumber() * (max - min + 1)))
end
Harness.Random = Random

function Harness.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = Harness.deepCopy(v)
	end
	return copy
end

local cache = {}
local overrides: { [string]: any } = {}
local extraGlobals: { [string]: any } = {}
local makeNode

-- Replace a module (by file path, e.g. "src/shared/Remotes.luau") with a mock.
function Harness.override(path: string, value: any)
	overrides[path] = value
end

-- Extra globals (game, task, warn, ...) for modules loaded after this call.
function Harness.setGlobals(globals: { [string]: any })
	for key, value in globals do
		extraGlobals[key] = value
	end
end

function Harness.resetCache()
	table.clear(cache)
end

local function loadFile(path: string)
	if overrides[path] ~= nil then
		return overrides[path]
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = fs.readFile(path)
	local dir = string.match(path, "^(.*)/[^/]+$")
	local environment = {
		script = { Parent = makeNode(dir), Name = path },
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Instance = roblox.Instance,
		Random = Random,
		require = Harness.require,
	}
	for key, value in extraGlobals do
		environment[key] = value
	end
	local chunk = luau.load(source, {
		debugName = path,
		environment = environment,
	})
	local result = chunk()
	cache[path] = result
	return result
end

-- Builds a plain table tree for a folder up front (Lune's fs calls can't run
-- inside metamethods).
local nodes = {}
function makeNode(dir: string)
	if nodes[dir] then
		return nodes[dir]
	end
	local node = { __path = dir, Name = string.match(dir, "[^/]+$") }
	nodes[dir] = node
	local parentDir = string.match(dir, "^(.*)/[^/]+$")
	if parentDir then
		node.Parent = makeNode(parentDir)
	end
	for _, entry in fs.readDir(dir) do
		local full = dir .. "/" .. entry
		if fs.isDir(full) then
			node[entry] = makeNode(full)
		elseif string.match(entry, "%.luau$") then
			local name = string.gsub(entry, "%.luau$", "")
			node[name] = { __file = full, Name = name }
		end
	end
	return node
end

function Harness.require(target: any)
	if type(target) == "table" and target.__file then
		return loadFile(target.__file)
	end
	return require(target)
end

function Harness.shared()
	return makeNode("src/shared")
end

function Harness.server()
	return makeNode("src/server")
end

function Harness.client()
	return makeNode("src/client")
end

return Harness
