--!strict
-- Attack and event poses, keyed by the action names the server sends
-- (BossService.PlayAction). Each action is a list of keyframes; poses are
-- added on top of the walk/idle pose and blended smoothly between keys.
--
-- A key's time is W * windup + D * duration + T seconds, so a pose can line up
-- with the ability's telegraph. Pose entries are { rx, ry, rz, px, py, pz }
-- (py in rig units). The first and last keys are empty so actions fade in/out.

export type Key = { W: number?, D: number?, T: number?, Pose: { [string]: { number } } }
export type Action = { Keys: { Key }, Shake: { At: Key, Strength: number, Radius: number }? }

local function arms(rx: number, rz: number, extra: { [string]: { number } }?): { [string]: { number } }
	local pose: { [string]: { number } } = {
		LeftShoulder = { rx, 0, -rz },
		RightShoulder = { rx, 0, rz },
	}
	if extra then
		for joint, value in extra do
			pose[joint] = value
		end
	end
	return pose
end

local Actions: { [string]: Action } = {}

-- Overhead right-handed strike.
Actions.Melee = {
	Keys = {
		{ T = 0, Pose = {} },
		{ W = 0.9, Pose = { RightShoulder = { 2.5, 0, 0.3 }, RightElbow = { 0.6, 0, 0 }, Waist = { 0.15, -0.35, 0 } } },
		{ W = 1, T = 0.12, Pose = { RightShoulder = { 0.3, 0, 0.1 }, RightElbow = { 0.15, 0, 0 }, Waist = { -0.35, 0.3, 0 }, Neck = { 0.1, 0, 0 } } },
		{ W = 1, T = 0.55, Pose = {} },
	},
}

-- Both arms overhead, then smashed down into a crouch.
Actions.Slam = {
	Keys = {
		{ T = 0, Pose = {} },
		{ W = 0.85, Pose = arms(2.8, 0.25, { LeftElbow = { 0.4, 0, 0 }, RightElbow = { 0.4, 0, 0 }, Waist = { 0.3, 0, 0 }, Neck = { 0.25, 0, 0 }, Root = { 0, 0, 0, 0, 0.1, 0 } }) },
		{ W = 1, T = 0.1, Pose = arms(0.9, 0.15, {
			LeftElbow = { 0.1, 0, 0 },
			RightElbow = { 0.1, 0, 0 },
			Waist = { -0.55, 0, 0 },
			Neck = { 0.2, 0, 0 },
			LeftHip = { 0.35, 0, 0 },
			RightHip = { 0.35, 0, 0 },
			LeftKnee = { -0.7, 0, 0 },
			RightKnee = { -0.7, 0, 0 },
			Root = { 0, 0, 0, 0, -0.35, 0 },
		}) },
		{ W = 1, T = 0.75, Pose = {} },
	},
	Shake = { At = { W = 1, T = 0.1, Pose = {} }, Strength = 0.8, Radius = 90 },
}

-- Crouch and lean in, then hold the lean for the dash.
local chargeLean = arms(-0.9, 0.2, { Waist = { -0.7, 0, 0 }, Neck = { 0.55, 0, 0 }, Jaw = { -0.3, 0, 0 } })
Actions.Charge = {
	Keys = {
		{ T = 0, Pose = {} },
		{ W = 0.9, Pose = arms(-0.6, 0.3, {
			Waist = { -0.5, 0, 0 },
			Neck = { 0.4, 0, 0 },
			LeftHip = { 0.4, 0, 0 },
			RightHip = { 0.4, 0, 0 },
			LeftKnee = { -0.6, 0, 0 },
			RightKnee = { -0.6, 0, 0 },
			Root = { 0, 0, 0, 0, -0.25, 0 },
			Jaw = { -0.35, 0, 0 },
		}) },
		{ W = 1, Pose = chargeLean },
		{ D = 1, Pose = chargeLean },
		{ D = 1, T = 0.35, Pose = {} },
	},
}

-- Vanish in a crouch, reappear with arms flung wide, strike down.
Actions.Blink = {
	Keys = {
		{ T = 0, Pose = arms(0.3, 0.6, { Waist = { -0.3, 0, 0 }, LeftKnee = { -0.4, 0, 0 }, RightKnee = { -0.4, 0, 0 }, Root = { 0, 0, 0, 0, -0.2, 0 } }) },
		{ W = 0.6, Pose = arms(1.6, 0.8, { Waist = { 0.2, 0, 0 }, Neck = { 0.2, 0, 0 } }) },
		{ W = 1, T = 0.1, Pose = arms(0.6, 0.3, { Waist = { -0.4, 0, 0 } }) },
		{ W = 1, T = 0.5, Pose = {} },
	},
}

-- Arms outstretched, head thrown back, drifting upward while it feeds.
local drainPose = arms(1.5, 0.35, { LeftElbow = { 0.1, 0, 0 }, RightElbow = { 0.1, 0, 0 }, Neck = { 0.45, 0, 0 }, Waist = { 0.25, 0, 0 }, Jaw = { -0.5, 0, 0 }, Root = { 0, 0, 0, 0, 0.25, 0 } })
Actions.Drain = {
	Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.5, Pose = drainPose },
		{ D = 1, T = -0.3, Pose = drainPose },
		{ D = 1, T = 0.3, Pose = {} },
	},
}

-- Arms raised to the sky, calling down the volley.
local skyPose = arms(3.0, 0.5, { Neck = { 0.5, 0, 0 }, Waist = { 0.2, 0, 0 }, Jaw = { -0.4, 0, 0 } })
Actions.Meteor = {
	Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.4, Pose = skyPose },
		{ W = 1, Pose = skyPose },
		{ W = 1, T = 0.5, Pose = {} },
	},
}

-- Gather in a crouch with arms crossed, then burst outward.
Actions.Nova = {
	Keys = {
		{ T = 0, Pose = {} },
		{ W = 0.8, Pose = {
			LeftShoulder = { 1.2, 0, 0.6 },
			RightShoulder = { 1.2, 0, -0.6 },
			LeftElbow = { 1.2, 0, 0 },
			RightElbow = { 1.2, 0, 0 },
			Waist = { -0.4, 0, 0 },
			LeftHip = { 0.3, 0, 0 },
			RightHip = { 0.3, 0, 0 },
			LeftKnee = { -0.6, 0, 0 },
			RightKnee = { -0.6, 0, 0 },
			Root = { 0, 0, 0, 0, -0.3, 0 },
		} },
		{ W = 1, T = 0.12, Pose = arms(1.4, 1.4, { Waist = { 0.3, 0, 0 }, Neck = { 0.3, 0, 0 }, Jaw = { -0.45, 0, 0 }, Root = { 0, 0, 0, 0, 0.2, 0 } }) },
		{ W = 1, T = 0.8, Pose = {} },
	},
	Shake = { At = { W = 1, T = 0.12, Pose = {} }, Strength = 0.5, Radius = 80 },
}

-- Enraged roar.
local roar = arms(0.5, 1.1, { LeftElbow = { 0.8, 0, 0 }, RightElbow = { 0.8, 0, 0 }, Waist = { 0.35, 0, 0 }, Neck = { 0.5, 0, 0 }, Jaw = { -0.7, 0, 0 } })
Actions.Enrage = {
	Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.3, Pose = roar },
		{ T = 1.1, Pose = roar },
		{ T = 1.5, Pose = {} },
	},
	Shake = { At = { T = 0.3, Pose = {} }, Strength = 0.4, Radius = 120 },
}

-- Rising out of the Dark Portal and roaring.
Actions.Spawn = {
	Keys = {
		{ T = 0, Pose = arms(-0.3, 0.1, { Waist = { -0.8, 0, 0 }, Neck = { -0.3, 0, 0 }, Root = { 0, 0, 0, 0, -0.6, 0 } }) },
		{ T = 1.2, Pose = roar },
		{ T = 1.9, Pose = roar },
		{ T = 2.4, Pose = {} },
	},
}

-- Collapse; held until the model dissolves.
local collapsed = arms(0.2, 0.2, {
	LeftHip = { 0.7, 0, 0 },
	RightHip = { 0.7, 0, 0 },
	LeftKnee = { -1.2, 0, 0 },
	RightKnee = { -1.2, 0, 0 },
	Waist = { -0.9, 0, 0 },
	Neck = { -0.5, 0, 0 },
	Jaw = { -0.5, 0, 0 },
	Root = { -0.2, 0, 0, 0, -0.45, 0 },
})
Actions.Death = {
	Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.7, Pose = collapsed },
		{ T = 600, Pose = collapsed },
	},
}

return Actions
