-- Checks the procedural animation math on real boss rigs (forward kinematics
-- outside Roblox): limbs swing the right way, wings rise, capes billow.
-- Run from the repo root with Lune: lune run tests/poses
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("./harness")

local CFrame = roblox.CFrame

Harness.setGlobals({
	game = {
		GetService = function(_, name)
			if name == "MaterialService" then
				return { FindFirstChild = function() return nil end }
			end
			error("unexpected service " .. name)
		end,
	},
})

local shared = Harness.shared()
local server = Harness.server()
local client = Harness.client()
local BossRoster = Harness.require(shared.Config.BossRoster)
local ModelKit = Harness.require(server.Bosses.Models.ModelKit)
local PoseSolver = Harness.require(client.Bosses.PoseSolver)
local AnimationStyles = Harness.require(client.Bosses.AnimationStyles)
local ActionPoses = Harness.require(client.Bosses.ActionPoses)

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- Every roster style is implemented, and every server action has a pose.
for _, name in BossRoster.AnimStyles do
	check(AnimationStyles[name] ~= nil, `AnimStyle {name} is not implemented`)
end
for name in AnimationStyles do
	check(table.find(BossRoster.AnimStyles, name) ~= nil, `AnimationStyles.{name} is not listed in BossRoster.AnimStyles`)
end
for _, action in { "Melee", "Slam", "Charge", "Blink", "Drain", "Meteor", "Nova", "Enrage", "Spawn", "Death" } do
	check(ActionPoses[action] ~= nil, `no pose for action {action}`)
end

-- Builds a boss and returns a function mapping a pose to world CFrames by part name.
local function rig(bossId: string)
	local def = BossRoster.Get(bossId)
	local stats = BossRoster.GetStats(def)
	local kit = ModelKit.new(def, stats.Scale)
	Harness.require(server.Bosses.Models.Designs[def.Id])(kit, def)
	local model = kit:Finish()

	local nextId = 0
	local byName = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			nextId += 1
			d:SetAttribute("_id", nextId)
			byName[d.Name] = byName[d.Name] or d
		end
	end
	local jointOf = {}
	local names = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			jointOf[d.Part1:GetAttribute("_id")] = d
			table.insert(names, d.Name)
		end
	end
	local rootId = model.PrimaryPart:GetAttribute("_id")

	local function solve(input)
		input.Style = input.Style or def.AnimStyle
		input.Scale = stats.Scale
		input.LegLength = model:GetAttribute("LegLength")
		input.Joints = names
		input.Time = input.Time or 0
		input.Phase = input.Phase or 0
		input.Walk = input.Walk or 0
		input.Speed = input.Speed or 0
		local pose = PoseSolver.Solve(input)
		local cache = {}
		local function world(part)
			local key = part:GetAttribute("_id")
			if cache[key] then
				return cache[key]
			end
			local result
			if key == rootId then
				result = part.CFrame
			else
				local joint = jointOf[key]
				result = world(joint.Part0) * joint.C0 * (pose[joint.Name] or CFrame.identity) * joint.C1:Inverse()
			end
			cache[key] = result
			return result
		end
		-- World position of a point given in a segment's rest (model) space.
		return function(segmentName: string, restPoint)
			local segment = byName[segmentName]
			return (world(segment) * segment.CFrame:Inverse() * CFrame.new(restPoint)).Position
		end
	end
	return solve, byName, stats.Scale
end

-- Legs and arms: at phase π/2 the left leg swings forward, the right one back,
-- and the arms swing the opposite way.
do
	local solve, parts = rig("cursed_skeleton")
	local at = solve({ Style = "March", Phase = math.pi / 2, Walk = 1, Speed = 9 })
	local leftFoot = at("LeftShin", parts.LeftShin.CFrame.Position - roblox.Vector3.new(0, parts.LeftShin.Size.Y / 2, 0))
	local rightFoot = at("RightShin", parts.RightShin.CFrame.Position - roblox.Vector3.new(0, parts.RightShin.Size.Y / 2, 0))
	local hip = at("Hips", parts.Hips.CFrame.Position)
	check(leftFoot.Z < hip.Z - 0.3, "left foot should be in front (-Z) at phase pi/2")
	check(rightFoot.Z > hip.Z + 0.3, "right foot should be behind at phase pi/2")
	local leftHand = at("LeftForearm", parts.LeftForearm.CFrame.Position)
	local rightHand = at("RightForearm", parts.RightForearm.CFrame.Position)
	check(rightHand.Z < leftHand.Z, "right arm should swing forward when the left leg does")

	-- Knees bend backwards: with a crouch the shin tilts back relative to the thigh.
	local crouch = solve({ Style = "Stalk", Phase = 0, Walk = 0 })
	local knee = crouch("LeftThigh", parts.LeftThigh.CFrame.Position - roblox.Vector3.new(0, parts.LeftThigh.Size.Y / 2, 0))
	local foot = crouch("LeftShin", parts.LeftShin.CFrame.Position - roblox.Vector3.new(0, parts.LeftShin.Size.Y / 2, 0))
	check(foot.Z > knee.Z, "a bent knee should put the foot behind the knee")
end

-- Scarecrow holds its left arm out to the side (-X).
do
	local solve, parts = rig("pumpkin_lord")
	local at = solve({ Walk = 0 })
	local shoulder = at("LeftUpperArm", parts.LeftUpperArm.CFrame.Position + roblox.Vector3.new(0, parts.LeftUpperArm.Size.Y / 2, 0))
	local hand = at("LeftForearm", parts.LeftForearm.CFrame.Position - roblox.Vector3.new(0, parts.LeftForearm.Size.Y / 2, 0))
	check(hand.X < shoulder.X - 1, "scarecrow's left arm should reach out to the left")
	check(math.abs(hand.Y - shoulder.Y) < 3, "scarecrow's left arm should be roughly horizontal")
end

-- Wings: a raise lifts both wing tips; the pose is mirror-symmetric.
do
	local solve, parts = rig("eclipse_seraph")
	local up = solve({ Style = "Soar", Time = math.pi / 2 / 1.2 })
	local down = solve({ Style = "Soar", Time = -math.pi / 2 / 1.2 })
	local tipOffset = roblox.Vector3.new(3, 0.5, 0.8)
	local wingRoot = parts.LeftWing.CFrame.Position
	local leftUp = up("LeftWing", wingRoot - tipOffset * roblox.Vector3.new(1, 0, 0) + roblox.Vector3.new(0, 0, 0))
	local leftDown = down("LeftWing", wingRoot - tipOffset * roblox.Vector3.new(1, 0, 0))
	check(leftUp.Y > leftDown.Y + 0.2, "left wing tip should rise on the upbeat")
	local rightRoot = parts.RightWing.CFrame.Position
	local rightUp = up("RightWing", rightRoot + tipOffset * roblox.Vector3.new(1, 0, 0))
	check(math.abs(rightUp.Y - leftUp.Y) < 0.05, "wings should beat symmetrically")
end

-- Capes billow backwards when moving.
do
	local solve, parts = rig("pale_king")
	local band = parts.CapeBand1
	local bottom = band.CFrame.Position - roblox.Vector3.new(0, band.Size.Y / 2, 0)
	local still = solve({ Walk = 0, Speed = 0 })("CapeBand1", bottom)
	local moving = solve({ Walk = 1, Speed = 9, Phase = 0 })("CapeBand1", bottom)
	check(moving.Z > still.Z + 0.2, "cape should billow backwards (+Z) when moving")
end

-- Orbit rings spin over time.
do
	local solve, parts = rig("crypt_lich")
	local point = parts.OrbitOrb.CFrame.Position
	local a = solve({ Time = 0 })("OrbitRing", point)
	local b = solve({ Time = 1 })("OrbitRing", point)
	check((a - b).Magnitude > 0.5, "orbit should move the orbs over time")
end

-- Actions blend in and out: nothing before the start or after the end.
do
	local action = { Name = "Slam", Elapsed = 0, Windup = 1.2, Duration = 2 }
	local base = PoseSolver.Solve({ Style = "Lumber", Scale = 2, LegLength = 2, Time = 0, Phase = 0, Walk = 0, Speed = 0 })
	action.Elapsed = 1.2 * 0.85
	local peak = PoseSolver.Solve({ Style = "Lumber", Scale = 2, LegLength = 2, Time = 0, Phase = 0, Walk = 0, Speed = 0, Action = action })
	local rx = select(1, peak.LeftShoulder:ToEulerAnglesXYZ())
	check(rx > 2, "slam windup should raise the arms overhead")
	action.Elapsed = 10
	local after = PoseSolver.Solve({ Style = "Lumber", Scale = 2, LegLength = 2, Time = 0, Phase = 0, Walk = 0, Speed = 0, Action = action })
	check((after.LeftShoulder.Position - base.LeftShoulder.Position).Magnitude < 1e-4 and select(1, after.LeftShoulder:ToEulerAnglesXYZ()) == select(1, base.LeftShoulder:ToEulerAnglesXYZ()), "finished actions leave no pose behind")
	local strength = PoseSolver.ShakeBetween({ Name = "Slam", Elapsed = 0, Windup = 1.2, Duration = 2 }, 1.2, 1.35)
	check(strength ~= nil, "slam impact should trigger a camera shake")
end

print("")
if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("All pose checks passed")
