--!strict
-- Animates boss rigs on each client.
--
-- Every frame (RunService.PreSimulation, after the Animator has run) it works
-- out how fast each boss is moving, advances its gait, and writes
-- Motor6D.Transform for every joint from PoseSolver. Transforms are local to
-- this client: nothing is replicated and the server's physics are untouched.
--
-- The server drives it through attributes on the boss model:
--   AnimStyle, BossScale, LegLength, ProceduralRig   set when the model is built
--   Action, ActionWindup, ActionDuration, ActionStart, ActionSeq   attacks/events
--   TargetUserId                                     who the boss is looking at
--   Enraged                                          fury tremble
--   UseAssetAnimations                               uploaded animations drive the
--                                                    body; only cloth, tails,
--                                                    wings and orbits are procedural

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = require(script.Parent.CameraShake)
local PoseSolver = require(script.Parent.PoseSolver)

local TAG = "Boss"
local MAX_DISTANCE = 800

type State = {
	Model: Model,
	Joints: { [string]: Motor6D },
	Names: { string },
	Style: string,
	Scale: number,
	LegLength: number,
	Phase: number,
	Walk: number,
	Speed: number,
	LastPosition: Vector3?,
	Seed: number,
	Action: PoseSolver.ActionState?,
	ActionStart: number,
	LastElapsed: number,
	LastStep: number,
	Connections: { RBXScriptConnection },
}

local BossAnimator = {}

local states: { [Model]: State } = {}

local function collectJoints(state: State)
	table.clear(state.Joints)
	table.clear(state.Names)
	for _, descendant in state.Model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			state.Joints[descendant.Name] = descendant
			table.insert(state.Names, descendant.Name)
		end
	end
end

local function readAction(state: State)
	local model = state.Model
	local name = model:GetAttribute("Action")
	local start = model:GetAttribute("ActionStart")
	if type(name) ~= "string" or type(start) ~= "number" then
		state.Action = nil
		return
	end
	state.ActionStart = start
	state.LastElapsed = Workspace:GetServerTimeNow() - start
	state.Action = {
		Name = name,
		Elapsed = state.LastElapsed,
		Windup = tonumber(model:GetAttribute("ActionWindup")) or 0.5,
		Duration = tonumber(model:GetAttribute("ActionDuration")) or 1,
	}
end

local function untrack(model: Model)
	local state = states[model]
	if not state then
		return
	end
	states[model] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or states[instance] then
		return
	end
	local model = instance
	if model:GetAttribute("ProceduralRig") ~= true then
		return
	end
	local seed = 0
	for i = 1, #model.Name do
		seed += string.byte(model.Name, i)
	end
	local state: State = {
		Model = model,
		Joints = {},
		Names = {},
		Style = tostring(model:GetAttribute("AnimStyle") or "March"),
		Scale = tonumber(model:GetAttribute("BossScale")) or 1,
		LegLength = tonumber(model:GetAttribute("LegLength")) or 2,
		Phase = 0,
		Walk = 0,
		Speed = 0,
		LastPosition = nil,
		Seed = seed % 100,
		Action = nil,
		ActionStart = 0,
		LastElapsed = 0,
		LastStep = 0,
		Connections = {},
	}
	states[model] = state
	collectJoints(state)
	readAction(state)

	table.insert(
		state.Connections,
		model.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Motor6D") then
				collectJoints(state)
			end
		end)
	)
	table.insert(
		state.Connections,
		model:GetAttributeChangedSignal("ActionSeq"):Connect(function()
			readAction(state)
		end)
	)
	table.insert(
		state.Connections,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				untrack(model)
			end
		end)
	)
end

local function lookAngles(state: State, root: BasePart): (number?, number?)
	local userId = state.Model:GetAttribute("TargetUserId")
	if type(userId) ~= "number" then
		return nil, nil
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not targetRoot:IsA("BasePart") then
		return nil, nil
	end
	local offset = root.CFrame:PointToObjectSpace(targetRoot.Position)
	local yaw = math.atan2(-offset.X, -offset.Z)
	local headHeight = 2.5 * state.Scale
	local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	local pitch = math.atan2(offset.Y - headHeight, math.max(flat, 1))
	return yaw, pitch
end

local function step(state: State, dt: number, now: number, cameraPosition: Vector3)
	local model = state.Model
	local root = model.PrimaryPart
	if not root then
		return
	end
	local position = root.Position
	if (position - cameraPosition).Magnitude > MAX_DISTANCE then
		return
	end

	-- Speed from how far the root moved (teleports such as Blink are ignored).
	if state.LastPosition and dt > 0 then
		local moved = Vector3.new(position.X - state.LastPosition.X, 0, position.Z - state.LastPosition.Z).Magnitude / dt
		if moved < 120 then
			state.Speed += (moved - state.Speed) * (1 - math.exp(-dt * 6))
		end
	end
	state.LastPosition = position
	local targetWalk = math.clamp((state.Speed - 0.4) / 3, 0, 1)
	state.Walk += (targetWalk - state.Walk) * (1 - math.exp(-dt * 5))
	if state.Walk > 0.02 then
		state.Phase += PoseSolver.PhaseRate(state.Style, state.LegLength, state.Scale, state.Speed) * dt
	end

	local style = PoseSolver.GetStyle(state.Style)
	-- Heavy bosses shake the ground on every footfall.
	local stepIndex = math.floor(state.Phase / math.pi)
	if stepIndex ~= state.LastStep then
		state.LastStep = stepIndex
		if style.Stomp and state.Walk > 0.5 then
			CameraShake.At(position, style.Stomp.Shake * math.min(state.Scale / 3, 1.5), style.Stomp.Radius * math.max(1, state.Scale / 3))
		end
	end

	local action = state.Action
	if action then
		local elapsed = Workspace:GetServerTimeNow() - state.ActionStart
		local strength, radius = PoseSolver.ShakeBetween(action, state.LastElapsed, elapsed)
		if strength and radius then
			CameraShake.At(position, strength, radius * math.max(1, state.Scale / 3))
		end
		state.LastElapsed = elapsed
		action.Elapsed = elapsed
	end

	local yaw, pitch = lookAngles(state, root)
	local pose = PoseSolver.Solve({
		Style = state.Style,
		Scale = state.Scale,
		LegLength = state.LegLength,
		Time = now,
		Phase = state.Phase,
		Walk = state.Walk,
		Speed = state.Speed,
		Action = action,
		LookYaw = yaw,
		LookPitch = pitch,
		Seed = state.Seed,
		Enraged = model:GetAttribute("Enraged") == true,
		Joints = state.Names,
		SecondaryOnly = model:GetAttribute("UseAssetAnimations") == true,
	})
	local secondaryOnly = model:GetAttribute("UseAssetAnimations") == true
	for name, joint in state.Joints do
		local transform = pose[name]
		if transform then
			joint.Transform = transform
		elseif not secondaryOnly then
			joint.Transform = CFrame.identity
		end
	end
end

function BossAnimator.Start()
	CameraShake.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("Model") then
			untrack(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end

	RunService.PreSimulation:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for _, state in states do
			local ok, err = pcall(step :: any, state, dt, now, cameraPosition)
			if not ok then
				warn(`[BossAnimator] {state.Model.Name}: {err}`)
				untrack(state.Model)
			end
		end
	end)
end

return BossAnimator
