--!strict
-- Walk/idle animation styles, one per boss (BossRoster.AnimStyle).
--
-- All angles are radians, distances are rig units (multiplied by the boss's
-- scale). Joint conventions (every joint frame is aligned with the root):
--   rx > 0 swings a hanging limb forward; on the Waist it leans the chest back
--   rz < 0 raises the LEFT arm/wing outward, rz > 0 raises the RIGHT one
--   ry > 0 turns left
--
-- Fields (all optional):
--   Legs   { Swing, Knee, Bend, Limp }  stride swing, knee lift, crouch, limp
--   Arms   { Swing, Elbow, ElbowSwing, Spread, Trail }
--   Body   { Bob, Roll, Lean, Twist, Hunch }
--   Head   { Bob, Counter, Jitter, JitterSpeed }
--   Idle   { Breath, Speed, Sway }
--   Float  { Height, Speed, Lean }        hovering bosses
--   Cadence                               gait cycles/second when floating
--   Jaw    { Open, Chatter, Speed }
--   Wings  { Flap, Speed, Rest, PairDelay }
--   Cape   { Wave, Speed, Billow }
--   Tail / Tentacles { Wave, Speed }
--   Orbit  { Speed }
--   FloatPieces { Bob, Speed }            detached armor pieces (Float1…)
--   Base   { [joint] = { rx, ry, rz } }   static pose on top of the rest pose
--   Extra  { { Joint, Axis (1 = rx, 2 = ry, 3 = rz), Amount, Speed, Phase } }  extra oscillators
--   Stomp  { Shake, Radius }              camera shake on each footfall

export type Style = { [string]: any }

local Styles: { [string]: Style } = {}

-- Cursed Skeleton: stiff soldier's march, rattling skull, chattering jaw,
-- shield held up and sword ready.
Styles.March = {
	Legs = { Swing = 0.5, Knee = 0.8, Bend = 0.08 },
	Arms = { Swing = 0.3, Elbow = 0.2, ElbowSwing = 0.1, Spread = 0.08 },
	Body = { Bob = 0.06, Roll = 0.03, Lean = 0.06, Twist = 0.05 },
	Head = { Bob = 0.03, Counter = 0.5, Jitter = 0.05, JitterSpeed = 11 },
	Jaw = { Open = 0.05, Chatter = 0.28, Speed = 14 },
	Idle = { Breath = 0.02, Speed = 1.4, Sway = 0.01 },
	Cape = { Wave = 0.08, Speed = 2, Billow = 0.45 },
	Base = { LeftShoulder = { 0.35, 0, -0.1 }, LeftElbow = { 1.0, 0, 0 }, RightShoulder = { 0.1, 0, 0.05 }, RightElbow = { 0.55, 0, 0 } },
}

-- Rotting Ghoul: lurching, limping shamble; knuckles near the floor, head lolling.
Styles.Shamble = {
	Legs = { Swing = 0.35, Knee = 0.6, Bend = 0.35, Limp = 0.6 },
	Arms = { Swing = 0.25, Elbow = 0.15, ElbowSwing = 0.1, Spread = 0.15 },
	Body = { Bob = 0.1, Roll = 0.13, Lean = 0.1, Twist = 0.12 },
	Head = { Bob = 0.08, Counter = 0.6, Jitter = 0.12, JitterSpeed = 5 },
	Jaw = { Open = 0.25, Chatter = 0.15, Speed = 3 },
	Idle = { Breath = 0.05, Speed = 1.1, Sway = 0.03 },
	Base = { LeftShoulder = { 0.35, 0, -0.15 }, RightShoulder = { 0.35, 0, 0.15 }, Neck = { 0.2, 0, 0.1 } },
}

-- Bog Hag: hunched, shuffling steps leaning on the staff, a clawed hand raised.
Styles.Hunch = {
	Legs = { Swing = 0.3, Knee = 0.5, Bend = 0.25 },
	Arms = { Swing = 0.12, Elbow = 0.1, Spread = 0.1 },
	Body = { Bob = 0.05, Roll = 0.08, Lean = 0.05, Twist = 0.05 },
	Head = { Bob = 0.06, Counter = 0.8, Jitter = 0.04, JitterSpeed = 3 },
	Idle = { Breath = 0.04, Speed = 1.2, Sway = 0.02 },
	Base = { RightShoulder = { 0.4, 0, 0.05 }, RightElbow = { 0.45, 0, 0 }, LeftShoulder = { 0.55, 0, -0.15 }, LeftElbow = { 1.0, 0, 0 } },
	Extra = { { Joint = "LeftElbow", Axis = 1, Amount = 0.15, Speed = 2.2, Phase = 0 } },
}

-- Wraith Knight: glides upright; its floating armor drifts apart and back.
Styles.GlideArmor = {
	Float = { Height = 0.2, Speed = 1.3, Lean = 0.15 },
	Cadence = 0.7,
	Arms = { Swing = 0.2, Elbow = 0.25, Spread = 0.12 },
	Body = { Roll = 0.04, Lean = 0.08, Twist = 0.05 },
	Head = { Counter = 0.6 },
	Idle = { Breath = 0.02, Speed = 1.2 },
	FloatPieces = { Bob = 0.14, Speed = 1.7 },
	Cape = { Wave = 0.12, Speed = 1.8, Billow = 0.8 },
	Base = { RightShoulder = { 0.25, 0, 0.05 }, RightElbow = { 0.6, 0, 0 }, LeftShoulder = { 0.1, 0, -0.12 } },
}

-- Plague Rat King: quick scurrying, twitchy sniffing, swinging censer, lashing tails.
Styles.Scurry = {
	Legs = { Swing = 0.45, Knee = 0.9, Bend = 0.3 },
	Arms = { Swing = 0.3, Elbow = 0.5, Spread = 0.1 },
	Body = { Bob = 0.08, Roll = 0.05, Lean = 0.1, Twist = 0.08 },
	Head = { Bob = 0.04, Counter = 0.7, Jitter = 0.1, JitterSpeed = 9 },
	Idle = { Breath = 0.05, Speed = 2.2 },
	Tail = { Wave = 0.35, Speed = 3 },
	Cape = { Wave = 0.1, Speed = 2.4, Billow = 0.5 },
	Base = { LeftShoulder = { 0.3, 0, -0.1 }, LeftElbow = { 0.9, 0, 0 }, RightShoulder = { 0.2, 0, 0.1 } },
	Extra = { { Joint = "RightShoulder", Axis = 1, Amount = 0.3, Speed = 2.4, Phase = 0 }, { Joint = "RightShoulder", Axis = 3, Amount = 0.12, Speed = 2.4, Phase = 1.2 } },
}

-- Gravebound Golem: slow, heavy lumber, rolling side to side; the ground shakes.
Styles.Lumber = {
	Legs = { Swing = 0.32, Knee = 0.35, Bend = 0.1 },
	Arms = { Swing = 0.4, Elbow = 0.2, Spread = 0.2 },
	Body = { Bob = 0.12, Roll = 0.12, Lean = 0.08, Twist = 0.1 },
	Head = { Bob = 0.02, Counter = 0.4 },
	Idle = { Breath = 0.015, Speed = 0.7, Sway = 0.01 },
	Stomp = { Shake = 0.35, Radius = 80 },
	Base = { LeftShoulder = { 0.1, 0, -0.2 }, RightShoulder = { 0.1, 0, 0.2 } },
}

-- Ancient Pumpkin Lord: loose-limbed puppet stride on stilt legs, one arm held
-- out like a scarecrow, flaming head lolling.
Styles.Scarecrow = {
	Legs = { Swing = 0.45, Knee = 0.4, Bend = 0.05 },
	Arms = { Swing = 0.1, Elbow = 0.1 },
	Body = { Bob = 0.1, Roll = 0.1, Lean = 0.04, Twist = 0.12 },
	Head = { Bob = 0.05, Counter = 0.5, Jitter = 0.06, JitterSpeed = 2.5 },
	Jaw = { Open = 0.12, Chatter = 0.1, Speed = 2 },
	Idle = { Breath = 0.02, Speed = 0.9, Sway = 0.03 },
	Cape = { Wave = 0.1, Speed = 1.7, Billow = 0.5 },
	Base = { LeftShoulder = { 0, 0, -1.3 }, LeftElbow = { 0.15, 0, 0 }, RightShoulder = { 0.35, 0, 0.3 }, RightElbow = { 0.6, 0, 0 }, Neck = { 0, 0, 0.25 } },
	Extra = { { Joint = "LeftShoulder", Axis = 3, Amount = 0.12, Speed = 1.6, Phase = 0 }, { Joint = "Neck", Axis = 3, Amount = 0.1, Speed = 0.8, Phase = 0.5 } },
}

-- Bloodmoon Werewolf: low, predatory stalk with long strides and claws forward.
Styles.Stalk = {
	Legs = { Swing = 0.55, Knee = 1.0, Bend = 0.45 },
	Arms = { Swing = 0.5, Elbow = 0.4, ElbowSwing = 0.2, Spread = 0.2 },
	Body = { Bob = 0.1, Roll = 0.05, Lean = 0.25, Twist = 0.1 },
	Head = { Bob = 0.05, Counter = 0.9 },
	Jaw = { Open = 0.15, Chatter = 0.06, Speed = 6 },
	Idle = { Breath = 0.05, Speed = 2 },
	Tail = { Wave = 0.2, Speed = 2 },
	Base = { LeftShoulder = { 0.45, 0, -0.25 }, RightShoulder = { 0.45, 0, 0.25 }, LeftElbow = { 0.5, 0, 0 }, RightElbow = { 0.5, 0, 0 } },
}

-- Crypt Lich: slow levitation, casting hand raised, soul shards orbiting.
Styles.Levitate = {
	Float = { Height = 0.3, Speed = 1.0, Lean = 0.05 },
	Cadence = 0.5,
	Arms = { Swing = 0.08, Elbow = 0.1, Spread = 0.2 },
	Body = { Roll = 0.03, Lean = 0.04 },
	Head = { Counter = 0.5 },
	Idle = { Breath = 0.03, Speed = 1.1 },
	Jaw = { Open = 0.05 },
	Orbit = { Speed = 0.8 },
	Cape = { Wave = 0.1, Speed = 1.5, Billow = 0.4 },
	Base = { RightShoulder = { 0.3, 0, 0.05 }, RightElbow = { 0.6, 0, 0 }, LeftShoulder = { 0.6, 0, -0.35 }, LeftElbow = { 0.9, 0, 0 } },
	Extra = { { Joint = "LeftShoulder", Axis = 1, Amount = 0.12, Speed = 1.3, Phase = 0 } },
}

-- Frostbound Banshee: swift glide, leaning forward with arms and veil streaming back.
Styles.Glide = {
	Float = { Height = 0.35, Speed = 1.5, Lean = 0.35 },
	Cadence = 0.9,
	Arms = { Swing = 0.12, Elbow = 0.2, Spread = 0.25, Trail = 0.7 },
	Body = { Roll = 0.05, Lean = 0.12 },
	Head = { Counter = 0.6 },
	Idle = { Breath = 0.03, Speed = 1.4 },
	Jaw = { Open = 0.35, Chatter = 0.12, Speed = 5 },
	Cape = { Wave = 0.18, Speed = 2.5, Billow = 0.9 },
	Orbit = { Speed = 1.2 },
	Base = { LeftShoulder = { 0.25, 0, -0.3 }, RightShoulder = { 0.25, 0, 0.3 } },
}

-- Abyssal Warden: heavy armored tread, face tentacles swaying like seaweed.
Styles.Tread = {
	Legs = { Swing = 0.35, Knee = 0.5, Bend = 0.15 },
	Arms = { Swing = 0.3, Elbow = 0.3, Spread = 0.2 },
	Body = { Bob = 0.1, Roll = 0.08, Lean = 0.08, Twist = 0.08 },
	Head = { Bob = 0.03, Counter = 0.5 },
	Idle = { Breath = 0.02, Speed = 0.9 },
	Tentacles = { Wave = 0.35, Speed = 1.6 },
	Stomp = { Shake = 0.25, Radius = 70 },
	Base = { RightElbow = { 0.3, 0, 0 }, LeftElbow = { 0.4, 0, 0 } },
}

-- Infernal Colossus: enormous stomping strides that shake the ground.
Styles.Stomp = {
	Legs = { Swing = 0.3, Knee = 0.35, Bend = 0.12 },
	Arms = { Swing = 0.35, Elbow = 0.25, Spread = 0.25 },
	Body = { Bob = 0.15, Roll = 0.1, Lean = 0.1, Twist = 0.12 },
	Head = { Bob = 0.02, Counter = 0.5 },
	Idle = { Breath = 0.02, Speed = 0.6 },
	Stomp = { Shake = 0.6, Radius = 110 },
	Base = { LeftShoulder = { 0.1, 0, -0.25 }, RightShoulder = { 0.1, 0, 0.25 } },
}

-- The Eclipse Seraph: soaring on six slow wingbeats, spear levelled.
Styles.Soar = {
	Float = { Height = 0.4, Speed = 0.9, Lean = 0.1 },
	Cadence = 0.5,
	Arms = { Swing = 0.08, Elbow = 0.1, Spread = 0.25 },
	Body = { Roll = 0.03, Lean = 0.05 },
	Head = { Counter = 0.5 },
	Idle = { Breath = 0.02, Speed = 1 },
	Wings = { Flap = 0.35, Speed = 1.2, Rest = 0.25, PairDelay = 0.35 },
	Base = { RightShoulder = { 0.5, 0, 0.05 }, RightElbow = { 0.5, 0, 0 }, LeftShoulder = { 0.2, 0, -0.4 }, LeftElbow = { 0.6, 0, 0 } },
}

-- Nyx'thal: a vast drifting mass; tentacles curl, wings beat slowly, the maw gnashes.
Styles.Drift = {
	Float = { Height = 0.45, Speed = 0.7, Lean = 0.08 },
	Cadence = 0.4,
	Arms = { Swing = 0.2, Elbow = 0.5, Spread = 0.35 },
	Body = { Roll = 0.05, Twist = 0.05 },
	Head = { Counter = 0.4, Jitter = 0.03, JitterSpeed = 1.5 },
	Idle = { Breath = 0.03, Speed = 0.6 },
	Jaw = { Open = 0.2, Chatter = 0.25, Speed = 1.5 },
	Wings = { Flap = 0.25, Speed = 0.8, Rest = 0.1 },
	Tentacles = { Wave = 0.45, Speed = 1.1 },
	Orbit = { Speed = 0.5 },
	Base = { LeftShoulder = { 0.5, 0, -0.3 }, RightShoulder = { 0.5, 0, 0.3 } },
}

-- The Pale King: slow, upright, imperious stride; the cape of state billows.
Styles.Regal = {
	Legs = { Swing = 0.35, Knee = 0.45, Bend = 0.04 },
	Arms = { Swing = 0.05, Elbow = 0.1, Spread = 0.15 },
	Body = { Bob = 0.04, Roll = 0.02, Twist = 0.03 },
	Head = { Bob = 0.01 },
	Idle = { Breath = 0.015, Speed = 0.8 },
	Cape = { Wave = 0.08, Speed = 1.4, Billow = 0.35 },
	Orbit = { Speed = 0.6 },
	Base = { RightShoulder = { 0.25, 0, 0.1 }, RightElbow = { 0.2, 0, 0 }, LeftShoulder = { 0.35, 0, -0.1 }, LeftElbow = { 1.1, 0, 0 } },
}

return Styles
