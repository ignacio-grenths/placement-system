--!strict

const PartBuilder = require("./PartBuilder")

-- Proportions of a figure at scale 1, in studs up from the point between its
-- soles. The big head is what reads as anime from the camera above.
const HIP_HEIGHT = 2.1
const HIP_SPACING = 0.38
const LEG_SIZE = Vector3.new(0.6, 2.1, 0.6)
const TORSO_SIZE = Vector3.new(1.5, 1.7, 0.8)
const SHOULDER_HEIGHT = 3.6
const SHOULDER_SPACING = 1.02
const ARM_SIZE = Vector3.new(0.5, 1.65, 0.5)
-- How far an arm reaches above its shoulder joint.
const ARM_OVERLAP = 0.2
const NECK_HEIGHT = 3.8
const HEAD_SIZE = Vector3.new(1.5, 1.56, 1.44)
const LASH_COLOR = Color3.fromRGB(25, 20, 32)
const HIGHLIGHT_COLOR = Color3.new(1, 1, 1)

-- Studs walked per full stride, at scale 1.
const STRIDE_LENGTH = 6
-- Studs per second at scale 1 that read as a full stride.
const FULL_STRIDE_SPEED = 12
-- Radians.
const LEG_SWING = 0.7
const ARM_SWING = 0.6
const RUN_LEAN = 0.15
const IDLE_ARM_SPREAD = 0.1
-- Studs, at scale 1.
const STRIDE_BOUNCE = 0.12
const BREATH_LIFT = 0.04
-- Radians per second.
const BREATH_SPEED = 2.2
-- How quickly the stride fades in and out, per second.
const MOVE_BLEND_RATE = 10
-- Studs in one frame, at scale 1, past which the unit was moved there, as by
-- a blink, rather than walked.
const MAX_STEP = 4
-- Seconds.
const ATTACK_DURATION = 0.4

export type RigBone = "Torso" | "Head" | "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg"
-- Slash swings overhead and DualSlash alternates hands. Shoot points at the
-- target.
export type AttackMotion = "Slash" | "DualSlash" | "Punch" | "Shoot"

export type RigSpec = {
	-- 1 is a figure about 5 studs tall.
	Scale: number?,
	-- Widens the torso and limbs for a heavier build. 1 when nil.
	Build: number?,
	SkinColor: Color3,
	HairColor: Color3,
	EyeColor: Color3,
	TopColor: Color3,
	-- Sleeves. TopColor when nil.
	ArmColor: Color3?,
	BottomColor: Color3,
	ShoeColor: Color3,
	AttackMotion: AttackMotion,
	-- Hair, clothes, and gear by the bone they ride on, placed from the bone's
	-- center on a figure of scale 1. The torso is 1.5 x 1.7 x 0.8, the head
	-- an ellipsoid 1.5 x 1.56 x 1.44, an arm 0.5 x 1.65 x 0.5 with its hand
	-- at Y -0.85, and a leg 0.6 x 2.1 x 0.6.
	Attachments: { [RigBone]: { PartBuilder.PartPlan }? },
}

export type Rig = {
	-- In the order of LAYOUTS, each anchored and moved on its own.
	Bones: { BasePart },
	-- The bones and everything attached to them.
	Parts: { BasePart },
	Scale: number,
	Motion: AttackMotion,
	-- Scaled joint positions and bone centers, by index in Bones.
	Joints: { Vector3 },
	Centers: { CFrame },
	StridePhase: number,
	-- 0 standing still to 1 at a full stride.
	MoveBlend: number,
	LastPosition: Vector3?,
	AttackStartTime: number?,
	AttackCount: number,
}

type BoneLayout = {
	Bone: RigBone,
	Shape: PartBuilder.PartShape,
	Size: Vector3,
	-- The joint the bone turns on.
	Joint: Vector3,
	-- From the joint to the bone's center.
	Center: Vector3,
	IsWidened: boolean,
}

-- How the attacking arm and the torso move at one moment of an attack.
type ArmPose = {
	-- Radians forward, from hanging down.
	Swing: number,
	-- Radians out to the side.
	Spread: number,
	-- Radians the torso turns toward the attacking side's opposite.
	Twist: number,
}

-- Bones are posed in this order, so the torso is placed before the bones
-- that hang from it.
const LAYOUTS: { BoneLayout } = {
	{
		Bone = "Torso",
		Shape = "Block",
		Size = TORSO_SIZE,
		Joint = Vector3.new(0, HIP_HEIGHT, 0),
		Center = Vector3.new(0, TORSO_SIZE.Y / 2, 0),
		IsWidened = true,
	},
	{
		Bone = "Head",
		Shape = "Ellipsoid",
		Size = HEAD_SIZE,
		Joint = Vector3.new(0, NECK_HEIGHT, 0),
		Center = Vector3.new(0, HEAD_SIZE.Y / 2, 0),
		IsWidened = false,
	},
	{
		Bone = "LeftArm",
		Shape = "Block",
		Size = ARM_SIZE,
		Joint = Vector3.new(-SHOULDER_SPACING, SHOULDER_HEIGHT, 0),
		Center = Vector3.new(0, ARM_OVERLAP - ARM_SIZE.Y / 2, 0),
		IsWidened = true,
	},
	{
		Bone = "RightArm",
		Shape = "Block",
		Size = ARM_SIZE,
		Joint = Vector3.new(SHOULDER_SPACING, SHOULDER_HEIGHT, 0),
		Center = Vector3.new(0, ARM_OVERLAP - ARM_SIZE.Y / 2, 0),
		IsWidened = true,
	},
	{
		Bone = "LeftLeg",
		Shape = "Block",
		Size = LEG_SIZE,
		Joint = Vector3.new(-HIP_SPACING, HIP_HEIGHT, 0),
		Center = Vector3.new(0, -LEG_SIZE.Y / 2, 0),
		IsWidened = true,
	},
	{
		Bone = "RightLeg",
		Shape = "Block",
		Size = LEG_SIZE,
		Joint = Vector3.new(HIP_SPACING, HIP_HEIGHT, 0),
		Center = Vector3.new(0, -LEG_SIZE.Y / 2, 0),
		IsWidened = true,
	},
}
const TORSO_INDEX = 1
const HEAD_INDEX = 2
const LEFT_ARM_INDEX = 3
const RIGHT_ARM_INDEX = 4
const LEFT_LEG_INDEX = 5
const RIGHT_LEG_INDEX = 6

const REST: ArmPose = { Swing = 0, Spread = IDLE_ARM_SPREAD, Twist = 0 }

-- Each attack winds up, strikes, and settles back to rest.
const ATTACK_TIMELINES: { [AttackMotion]: { Moments: { number }, Poses: { ArmPose } } } = {
	Slash = {
		Moments = { 0, 0.35, 0.6, 1 },
		Poses = {
			REST,
			{ Swing = 2.6, Spread = 0.3, Twist = -0.35 },
			{ Swing = -0.3, Spread = 0.1, Twist = 0.4 },
			REST,
		},
	},
	DualSlash = {
		Moments = { 0, 0.3, 0.55, 1 },
		Poses = {
			REST,
			{ Swing = 1.4, Spread = 1.2, Twist = -0.4 },
			{ Swing = 1.3, Spread = -0.5, Twist = 0.45 },
			REST,
		},
	},
	Punch = {
		Moments = { 0, 0.25, 0.5, 1 },
		Poses = {
			REST,
			{ Swing = -0.6, Spread = 0.2, Twist = -0.4 },
			{ Swing = 1.6, Spread = 0, Twist = 0.45 },
			REST,
		},
	},
	Shoot = {
		Moments = { 0, 0.15, 0.3, 0.65, 1 },
		Poses = {
			REST,
			{ Swing = 1.6, Spread = 0, Twist = 0.2 },
			{ Swing = 1.35, Spread = 0, Twist = 0.25 },
			{ Swing = 1.6, Spread = 0, Twist = 0.2 },
			REST,
		},
	},
}

local Module = {}

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) ^ 2
end

--[[
	Runs through poses at the given moments of an attack, 0 to 1, easing
	between neighbors. The first moment must be 0 and the last 1.
]]
local function blendPoses(moments: { number }, poses: { ArmPose }, progress: number): ArmPose
	for index = 2, #moments do
		if progress <= moments[index] then
			local from = poses[index - 1]
			local to = poses[index]
			local alpha =
				easeOut((progress - moments[index - 1]) / (moments[index] - moments[index - 1]))
			return {
				Swing = lerp(from.Swing, to.Swing, alpha),
				Spread = lerp(from.Spread, to.Spread, alpha),
				Twist = lerp(from.Twist, to.Twist, alpha),
			}
		end
	end
	return poses[#poses]
end

--[[
	A point on the front of the head. across and up run from -1 to 1 over
	the face; out pushes the point off the surface.
]]
local function onFace(across: number, up: number, out: number): Vector3
	local inside = math.max(0, 1 - across ^ 2 - up ^ 2)
	return Vector3.new(
		across * HEAD_SIZE.X / 2,
		up * HEAD_SIZE.Y / 2,
		-HEAD_SIZE.Z / 2 * math.sqrt(inside) - out
	)
end

--[[
	Big anime eyes with a shine and a lash line, and a small mouth, each
	turned to follow the curve of the face.
]]
local function planFace(spec: RigSpec): { PartBuilder.PartPlan }
	local plans: { PartBuilder.PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.19, 0.04, 0.06),
			Offset = CFrame.new(onFace(0, -0.5, 0)),
			Color = spec.SkinColor:Lerp(LASH_COLOR, 0.6),
		},
	}
	for _, side in { -1, 1 } do
		local across = side * 0.36
		local turn = CFrame.Angles(0, -across * 0.6, 0)
		local eye = onFace(across, -0.08, -0.05)
		table.insert(plans, {
			Shape = "Ellipsoid",
			Size = Vector3.new(0.29, 0.41, 0.14),
			Offset = CFrame.new(eye) * turn,
			Color = spec.EyeColor,
		})
		table.insert(plans, {
			Shape = "Ball",
			Size = Vector3.one * 0.11,
			Offset = CFrame.new(eye + Vector3.new(-side * 0.05, 0.085, -0.06)),
			Color = HIGHLIGHT_COLOR,
			Material = Enum.Material.Neon,
		})
		table.insert(plans, {
			Shape = "Block",
			Size = Vector3.new(0.36, 0.07, 0.09),
			Offset = CFrame.new(eye + Vector3.new(0, 0.22, -0.01))
				* turn
				* CFrame.Angles(0, 0, side * -0.15),
			Color = LASH_COLOR,
		})
	end
	return plans
end

local function planDetails(spec: RigSpec, bone: RigBone): { PartBuilder.PartPlan }
	if bone == "Head" then
		local face = planFace(spec)
		table.insert(face, {
			Shape = "Cylinder",
			Size = Vector3.new(0.42, 0.4, 0.42),
			Offset = CFrame.new(0, -HEAD_SIZE.Y / 2 - 0.05, 0.05),
			Color = spec.SkinColor,
		})
		return face
	elseif bone == "LeftArm" or bone == "RightArm" then
		return {
			{
				Shape = "Ellipsoid",
				Size = Vector3.new(0.5, 0.5, 0.5),
				Offset = CFrame.new(0, -0.85, 0),
				Color = spec.SkinColor,
			},
		}
	elseif bone == "LeftLeg" or bone == "RightLeg" then
		return {
			{
				Shape = "Block",
				Size = Vector3.new(0.66, 0.32, 0.86),
				Offset = CFrame.new(0, 0.16 - LEG_SIZE.Y / 2, -0.12),
				Color = spec.ShoeColor,
			},
		}
	end
	return {}
end

local function getBoneColor(spec: RigSpec, bone: RigBone): Color3
	if bone == "Head" then
		return spec.SkinColor
	elseif bone == "Torso" then
		return spec.TopColor
	elseif bone == "LeftArm" or bone == "RightArm" then
		return spec.ArmColor or spec.TopColor
	end
	return spec.BottomColor
end

local function stretchPlan(plan: PartBuilder.PartPlan, stretch: Vector3): PartBuilder.PartPlan
	local stretched = table.clone(plan)
	stretched.Size = plan.Size * stretch
	stretched.Offset = CFrame.new(plan.Offset.Position * stretch) * plan.Offset.Rotation
	return stretched
end

--[[
	Builds the figure's parts at the origin. sizeScale multiplies the spec's
	own scale, for a unit drawn larger than usual.
]]
function Module.build(spec: RigSpec, transparency: number, sizeScale: number): Rig
	local scale = (spec.Scale or 1) * sizeScale
	local build = spec.Build or 1
	local jointStretch = Vector3.new(scale * build, scale, scale)
	local bones = {}
	local parts = {}
	local joints = {}
	local centers = {}

	for _, layout in LAYOUTS do
		local width = if layout.IsWidened then build else 1
		local stretch = Vector3.new(scale * width, scale, scale * width)
		local bone = PartBuilder.create({
			Shape = layout.Shape,
			Size = layout.Size * stretch,
			Offset = CFrame.identity,
			Color = getBoneColor(spec, layout.Bone),
		}, transparency)
		bone.CanQuery = false
		table.insert(bones, bone)
		table.insert(parts, bone)

		local plans = planDetails(spec, layout.Bone)
		local attachments: { PartBuilder.PartPlan } = spec.Attachments[layout.Bone] or {}
		for _, plan in attachments do
			table.insert(plans, plan)
		end
		for _, plan in plans do
			local part = PartBuilder.create(stretchPlan(plan, stretch), transparency)
			PartBuilder.attach(part, bone)
			table.insert(parts, part)
		end

		table.insert(joints, layout.Joint * jointStretch)
		table.insert(centers, CFrame.new(layout.Center * stretch))
	end

	return {
		Bones = bones,
		Parts = parts,
		Scale = scale,
		Motion = spec.AttackMotion,
		Joints = joints,
		Centers = centers,
		StridePhase = 0,
		MoveBlend = 0,
		LastPosition = nil,
		AttackStartTime = nil,
		AttackCount = 0,
	}
end

function Module.startAttack(rig: Rig, now: number)
	rig.AttackStartTime = now
	rig.AttackCount += 1
end

--[[
	Poses the rig standing at feet, which faces the way the unit does, and
	appends each bone with its new CFrame to parts and cframes for one bulk
	move. The stride follows how far feet moved since the last call.
]]
function Module.pose(
	rig: Rig,
	feet: CFrame,
	deltaTime: number,
	now: number,
	parts: { BasePart },
	cframes: { CFrame }
)
	local scale = rig.Scale
	local position = feet.Position
	local lastPosition = rig.LastPosition
	rig.LastPosition = position
	local moved = if lastPosition
		then Vector3.new(position.X - lastPosition.X, 0, position.Z - lastPosition.Z).Magnitude
		else 0
	if moved > MAX_STEP * scale then
		moved = 0
	end

	local speed = if deltaTime > 0 then moved / deltaTime else 0
	local targetBlend = math.clamp(speed / (FULL_STRIDE_SPEED * scale), 0, 1)
	rig.MoveBlend += (targetBlend - rig.MoveBlend) * math.min(1, deltaTime * MOVE_BLEND_RATE)
	rig.StridePhase = (rig.StridePhase + moved / (STRIDE_LENGTH * scale) * 2 * math.pi)
		% (2 * math.pi)
	local blend = rig.MoveBlend
	local stride = math.sin(rig.StridePhase)

	local attack: ArmPose? = nil
	local attackStartTime = rig.AttackStartTime
	if attackStartTime then
		local progress = (now - attackStartTime) / ATTACK_DURATION
		if progress >= 1 then
			rig.AttackStartTime = nil
		else
			local timeline = ATTACK_TIMELINES[rig.Motion]
			attack = blendPoses(timeline.Moments, timeline.Poses, progress)
		end
	end
	local isLeftAttack = rig.Motion == "DualSlash" and rig.AttackCount % 2 == 0

	local breath = math.sin(now * BREATH_SPEED)
	local bounce = math.abs(math.cos(rig.StridePhase)) * STRIDE_BOUNCE * blend * scale
	local lean = -RUN_LEAN * blend
	local legSwing = stride * LEG_SWING * blend
	local leftSwing = -stride * ARM_SWING * blend
	local rightSwing = stride * ARM_SWING * blend
	local leftSpread = IDLE_ARM_SPREAD
	local rightSpread = IDLE_ARM_SPREAD
	local twist = 0
	if attack and isLeftAttack then
		leftSwing = attack.Swing
		leftSpread = attack.Spread
		twist = -attack.Twist
	elseif attack then
		rightSwing = attack.Swing
		rightSpread = attack.Spread
		twist = attack.Twist
	end

	local joints = rig.Joints
	local torsoJoint = joints[TORSO_INDEX]
	local hips = feet * CFrame.new(0, bounce, 0)
	local torso = hips
		* CFrame.new(torsoJoint + Vector3.new(0, breath * BREATH_LIFT * scale, 0))
		* CFrame.Angles(lean, twist, 0)
	local function fromTorso(index: number, angles: CFrame): CFrame
		return torso * CFrame.new(joints[index] - torsoJoint) * angles
	end

	local frames = {
		torso,
		fromTorso(HEAD_INDEX, CFrame.Angles(-lean * 0.6, -twist * 0.6, 0)),
		fromTorso(LEFT_ARM_INDEX, CFrame.Angles(leftSwing, 0, -leftSpread)),
		fromTorso(RIGHT_ARM_INDEX, CFrame.Angles(rightSwing, 0, rightSpread)),
		hips * CFrame.new(joints[LEFT_LEG_INDEX]) * CFrame.Angles(legSwing, 0, 0),
		hips * CFrame.new(joints[RIGHT_LEG_INDEX]) * CFrame.Angles(-legSwing, 0, 0),
	}
	for index, bone in rig.Bones do
		table.insert(parts, bone)
		table.insert(cframes, frames[index] * rig.Centers[index])
	end
end

return Module
