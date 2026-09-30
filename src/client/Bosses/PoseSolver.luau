--!strict
-- Pure pose math for the boss animations: given a style, the gait phase, how
-- much the boss is walking and any action in progress, returns the
-- Motor6D.Transform for each joint. No Roblox services, so it runs (and is
-- tested) outside the game too.

local ActionPoses = require(script.Parent.ActionPoses)
local AnimationStyles = require(script.Parent.AnimationStyles)

export type ActionState = { Name: string, Elapsed: number, Windup: number, Duration: number }

export type Input = {
	Style: string,
	Scale: number,
	LegLength: number, -- rig units
	Time: number,
	Phase: number, -- gait phase, radians
	Walk: number, -- 0 (idle) … 1 (walking)
	Speed: number, -- studs/second
	Action: ActionState?,
	LookYaw: number?,
	LookPitch: number?,
	Seed: number?,
	Enraged: boolean?,
	Joints: { string }?, -- joints present in the model (for chains like Cape1…n)
	SecondaryOnly: boolean?, -- only cloth/tails/wings/orbits (uploaded animations drive the body)
}

type Values = { number } -- rx, ry, rz, px, py, pz

local PoseSolver = {}

local TWO_PI = math.pi * 2
local PRIMARY = {
	Root = true,
	Waist = true,
	Neck = true,
	LeftShoulder = true,
	RightShoulder = true,
	LeftElbow = true,
	RightElbow = true,
	LeftHip = true,
	RightHip = true,
	LeftKnee = true,
	RightKnee = true,
}

local function add(pose: { [string]: Values }, joint: string, rx: number, ry: number?, rz: number?, px: number?, py: number?, pz: number?)
	local values = pose[joint]
	if not values then
		values = { 0, 0, 0, 0, 0, 0 }
		pose[joint] = values
	end
	values[1] += rx
	values[2] += ry or 0
	values[3] += rz or 0
	values[4] += px or 0
	values[5] += py or 0
	values[6] += pz or 0
end

-- Adds weighted { rx, ry, rz, px, py, pz }; translations are in rig units and
-- multiplied by `scale`.
local function addValues(pose: { [string]: Values }, joint: string, v: { number }, weight: number, scale: number?)
	local k = weight * (scale or 1)
	add(pose, joint, (v[1] or 0) * weight, (v[2] or 0) * weight, (v[3] or 0) * weight, (v[4] or 0) * k, (v[5] or 0) * k, (v[6] or 0) * k)
end

-- Cheap smooth noise in [-1, 1].
local function wobble(t: number, seed: number): number
	return (math.sin(t * 1.7 + seed) + math.sin(t * 2.9 + seed * 1.3) * 0.6) / 1.6
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function PoseSolver.GetStyle(name: string): AnimationStyles.Style
	return AnimationStyles[name] or AnimationStyles.March
end

-- How fast the gait phase advances (radians/second) at `speed` studs/second.
-- Legged styles match stride length to leg length so feet don't slide.
function PoseSolver.PhaseRate(styleName: string, legLength: number, scale: number, speed: number): number
	local style = PoseSolver.GetStyle(styleName)
	if style.Float or not style.Legs then
		local cadence = style.Cadence or 0.8
		return cadence * TWO_PI * math.clamp(speed / 6, 0.25, 1.5)
	end
	local stride = math.max(0.5, 4 * legLength * math.sin(style.Legs.Swing) * scale)
	return speed / stride * TWO_PI
end

local function keyTime(key: ActionPoses.Key, action: ActionState): number
	return (key.W or 0) * action.Windup + (key.D or 0) * action.Duration + (key.T or 0)
end

-- Adds the current action pose; returns how strongly the action overrides walking.
local function applyAction(pose: { [string]: Values }, action: ActionState, scale: number): number
	local definition = ActionPoses[action.Name]
	if not definition then
		return 0
	end
	local keys = definition.Keys
	local elapsed = action.Elapsed
	local first, last = keyTime(keys[1], action), keyTime(keys[#keys], action)
	if elapsed < first or elapsed > last then
		return 0
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		local ta, tb = keyTime(a, action), keyTime(b, action)
		if elapsed >= ta and elapsed <= tb then
			local alpha = if tb > ta then smooth((elapsed - ta) / (tb - ta)) else 1
			for joint, values in a.Pose do
				addValues(pose, joint, values, 1 - alpha, scale)
			end
			for joint, values in b.Pose do
				addValues(pose, joint, values, alpha, scale)
			end
			break
		end
	end
	return math.min(1, (elapsed - first) / 0.15, (last - elapsed) / 0.15)
end

-- Whether a Slam/Nova/Enrage impact just happened between two elapsed times.
function PoseSolver.ShakeBetween(action: ActionState, from: number, to: number): (number?, number?)
	local definition = ActionPoses[action.Name]
	if not definition or not definition.Shake then
		return nil, nil
	end
	local at = keyTime(definition.Shake.At, action)
	if at > from and at <= to then
		return definition.Shake.Strength, definition.Shake.Radius
	end
	return nil, nil
end

-- Parses "Cape2" → "Cape", 2.
local function chain(name: string): (string?, number?)
	local prefix, index = string.match(name, "^(%a-)(%d+)$")
	if prefix and index then
		return prefix, tonumber(index)
	end
	return nil, nil
end

function PoseSolver.Solve(input: Input): { [string]: CFrame }
	local style = PoseSolver.GetStyle(input.Style)
	local pose: { [string]: Values } = {}
	local t = input.Time
	local p = input.Phase
	local s = input.Scale
	local seed = input.Seed or 0
	local speedFactor = math.clamp(input.Speed / 8, 0, 1.5)

	local actionWeight = 0
	if input.Action then
		actionWeight = applyAction(pose, input.Action, s)
	end
	local w = input.Walk * (1 - actionWeight * 0.85)

	-- Static base pose.
	if style.Base then
		for joint, values in style.Base do
			addValues(pose, joint, values, 1)
		end
	end

	-- Idle breathing and sway.
	local idle = style.Idle
	if idle then
		local breath = math.sin(t * (idle.Speed or 1) * 1.6)
		local calm = 1 - w * 0.5
		add(pose, "Waist", breath * (idle.Breath or 0) * calm)
		add(pose, "Neck", -breath * (idle.Breath or 0) * 0.6 * calm)
		add(pose, "LeftShoulder", 0, 0, -breath * (idle.Breath or 0) * 0.5 * calm)
		add(pose, "RightShoulder", 0, 0, breath * (idle.Breath or 0) * 0.5 * calm)
		add(pose, "Root", 0, 0, math.sin(t * (idle.Speed or 1) * 0.5 + seed) * (idle.Sway or 0))
	end

	-- Legs.
	local legs = style.Legs
	if legs then
		local limp = legs.Limp or 0
		local swing = (legs.Swing or 0) * w
		local knee = legs.Knee or 0
		local bend = legs.Bend or 0
		local leftPhase, rightPhase = p, p + math.pi + limp * 0.6
		add(pose, "LeftHip", math.sin(leftPhase) * swing + bend * 0.5)
		add(pose, "RightHip", math.sin(rightPhase) * swing * (1 - limp * 0.5) + bend * 0.5)
		add(pose, "LeftKnee", -(math.max(0, math.cos(leftPhase)) * knee * w + bend))
		add(pose, "RightKnee", -(math.max(0, math.cos(rightPhase)) * knee * w * (1 - limp * 0.6) + bend))
		-- Crouching lowers the hips so the feet stay on the ground.
		add(pose, "Root", 0, 0, 0, 0, -input.LegLength * (1 - math.cos(bend * 0.5)) * s)
	end

	-- Arms swing opposite to the legs.
	local arms = style.Arms
	if arms then
		local armSwing = (arms.Swing or 0) * w
		local spread = arms.Spread or 0
		local trail = (arms.Trail or 0) * w
		add(pose, "LeftShoulder", math.sin(p + math.pi) * armSwing - trail, 0, -spread)
		add(pose, "RightShoulder", math.sin(p) * armSwing - trail, 0, spread)
		local elbowSwing = arms.ElbowSwing or 0
		add(pose, "LeftElbow", (arms.Elbow or 0) + math.max(0, math.sin(p + math.pi)) * elbowSwing * w)
		add(pose, "RightElbow", (arms.Elbow or 0) + math.max(0, math.sin(p)) * elbowSwing * w)
	end

	-- Body bob, sway, lean and twist.
	local body = style.Body or {}
	local head = style.Head or {}
	local lean = (body.Lean or 0) * w + (body.Hunch or 0)
	add(pose, "Root", 0, 0, math.sin(p) * (body.Roll or 0) * w, 0, math.cos(2 * p) * (body.Bob or 0) * w * s)
	add(pose, "Waist", -lean, math.sin(p) * (body.Twist or 0) * w)
	add(pose, "Neck", lean * (head.Counter or 0.5) + math.cos(2 * p) * (head.Bob or 0) * w, -math.sin(p) * (body.Twist or 0) * w * 0.6)
	if head.Jitter then
		local speed = head.JitterSpeed or 6
		add(pose, "Neck", wobble(t * speed, seed) * head.Jitter, wobble(t * speed * 0.8, seed + 2) * head.Jitter * 0.7, wobble(t * speed * 1.2, seed + 4) * head.Jitter * 0.5)
	end

	-- Hovering.
	local float = style.Float
	if float then
		add(pose, "Root", -math.min(speedFactor, 1) * (float.Lean or 0), 0, 0, 0, math.sin(t * (float.Speed or 1)) * (float.Height or 0) * s)
	end

	-- Looking at the current target.
	if input.LookYaw then
		local yaw = math.clamp(input.LookYaw, -1.1, 1.1) * (1 - actionWeight * 0.5)
		add(pose, "Neck", 0, yaw * 0.7)
		add(pose, "Waist", 0, yaw * 0.25)
	end
	if input.LookPitch then
		add(pose, "Neck", math.clamp(input.LookPitch, -0.5, 0.6) * 0.6 * (1 - actionWeight * 0.5))
	end

	-- Jaw.
	local jaw = style.Jaw
	if jaw then
		local chatter = math.max(0, math.sin(t * (jaw.Speed or 6))) * (jaw.Chatter or 0)
		add(pose, "Jaw", -((jaw.Open or 0) + chatter + (if input.Enraged then 0.15 else 0)))
	end

	-- Extra oscillators.
	if style.Extra then
		for _, extra in style.Extra do
			local value = math.sin(t * extra.Speed + (extra.Phase or 0)) * extra.Amount
			local v = { 0, 0, 0 }
			v[extra.Axis] = value
			addValues(pose, extra.Joint, v, 1)
		end
	end

	-- Enraged bosses tremble with fury.
	if input.Enraged then
		add(pose, "Waist", wobble(t * 18, seed) * 0.02, 0, wobble(t * 16, seed + 1) * 0.02)
	end

	-- Chains and secondary pieces.
	local wings, cape, tail, tentacles = style.Wings, style.Cape, style.Tail, style.Tentacles
	local orbit, pieces = style.Orbit, style.FloatPieces
	local joints: { string } = input.Joints or {}
	for _, name in joints do
		if PRIMARY[name] or name == "Jaw" then
			continue
		end
		local prefix, index = chain(name)
		if prefix == "Cape" and cape and index then
			local billow = (cape.Billow or 0) * math.min(speedFactor, 1) * (if index == 1 then 1 else 0.45)
			add(pose, name, -billow + math.sin(t * (cape.Speed or 2) - index * 0.9 + seed) * (cape.Wave or 0), 0, math.sin(t * (cape.Speed or 2) * 0.6 - index) * (cape.Wave or 0) * 0.4)
		elseif (prefix == "Tail" or prefix == "TailB" or prefix == "TailC") and tail and index then
			local offset = if prefix == "TailB" then 1.7 elseif prefix == "TailC" then 3.1 else 0
			local amount = (tail.Wave or 0) * (1 + speedFactor * 0.5)
			add(pose, name, math.sin(t * (tail.Speed or 2) + index * 0.8 + offset) * amount * 0.6, math.sin(t * (tail.Speed or 2) * 0.8 + index * 0.6 + offset) * amount)
		elseif prefix and string.sub(prefix, 1, 8) == "Tentacle" and tentacles and index then
			local offset = (string.byte(prefix, -1) or 65) * 1.37
			local amount = tentacles.Wave or 0
			add(pose, name, math.sin(t * (tentacles.Speed or 1.5) + index * 0.7 + offset) * amount, 0, math.sin(t * (tentacles.Speed or 1.5) * 0.7 + index * 0.9 + offset) * amount * 0.8)
		elseif name == "Orbit" and orbit then
			add(pose, name, 0, t * (orbit.Speed or 1))
		elseif prefix == "Float" and pieces and index then
			local speed = pieces.Speed or 1.5
			add(pose, name, math.sin(t * speed * 0.7 + index) * 0.05, 0, math.sin(t * speed * 0.6 + index * 2) * 0.04, 0, math.sin(t * speed + index * 1.3) * (pieces.Bob or 0) * s)
		elseif wings and (string.sub(name, 1, 8) == "LeftWing" or string.sub(name, 1, 9) == "RightWing") then
			local pair = tonumber(string.match(name, "(%d+)$")) or 1
			local side = if string.sub(name, 1, 4) == "Left" then -1 else 1
			local beat = math.sin(t * (wings.Speed or 1) * (1 + speedFactor * 0.3) - (pair - 1) * (wings.PairDelay or 0.3))
			local raise = ((wings.Rest or 0) + beat * (wings.Flap or 0)) * (1 - (pair - 1) * 0.15)
			add(pose, name, 0, side * -beat * 0.12, side * raise)
		end
	end

	-- Build CFrames.
	local result: { [string]: CFrame } = {}
	for joint, v in pose do
		if input.SecondaryOnly and (PRIMARY[joint] or joint == "Jaw") then
			continue
		end
		result[joint] = CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(v[1], v[2], v[3])
	end
	return result
end

return PoseSolver
