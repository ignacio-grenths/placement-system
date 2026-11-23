--!strict

const CharacterRig = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/UnitVisualsSystem/SystemPackage/CharacterRig"
)
const PartBuilder = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/UnitVisualsSystem/SystemPackage/PartBuilder"
)

type PartPlan = PartBuilder.PartPlan
type RigSpec = CharacterRig.RigSpec

type BladeOptions = {
	Length: number,
	GuardColor: Color3,
	-- Steel when nil.
	BladeColor: Color3?,
	-- A glowing strip along the blade's top edge.
	EdgeColor: Color3?,
	-- Radians the last stretch of the blade bends up, for a curved sword.
	Bend: number?,
}

-- Every place on a figure below is in studs from the center of the bone it
-- rides on, for a figure of scale 1, with -Z as the front. The head is an
-- ellipsoid 1.5 x 1.56 x 1.44, the torso 1.5 x 1.7 x 0.8, and a hand sits at
-- Y -0.85 on its arm.

const STEEL = Color3.fromRGB(212, 218, 230)
const GRIP_COLOR = Color3.fromRGB(35, 30, 30)
-- Covers the top and back of the head down to the brows.
const HAIR_CAP_SIZE = Vector3.new(1.68, 1.26, 1.61)
const HAIR_CAP_OFFSET = CFrame.new(0, 0.31, 0.08)
const BEND_LENGTH = 0.5

local Module = {}

--[[
	A tapered lock of hair, or any pointed piece, running from root to tip.
]]
local function lock(color: Color3, root: Vector3, tip: Vector3, width: number): PartPlan
	local along = tip - root
	local up = along.Unit
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 0.01 then
		right = Vector3.xAxis
	end
	return {
		Shape = "Ellipsoid",
		Size = Vector3.new(width, along.Magnitude, width * 0.8),
		Offset = CFrame.fromMatrix(root + along / 2, right.Unit, up),
		Color = color,
	}
end

--[[
	The same piece on the other side of the figure.
]]
local function mirrored(plan: PartPlan): PartPlan
	local mirror = table.clone(plan)
	local position = plan.Offset.Position
	local x, y, z = plan.Offset:ToEulerAnglesYXZ()
	mirror.Offset = CFrame.new(-position.X, position.Y, position.Z)
		* CFrame.fromEulerAnglesYXZ(x, -y, -z)
	return mirror
end

--[[
	Returns the pieces followed by their mirror images.
]]
local function withMirrors(plans: { PartPlan }): { PartPlan }
	local both = table.clone(plans)
	for _, plan in plans do
		table.insert(both, mirrored(plan))
	end
	return both
end

local function glowing(plan: PartPlan): PartPlan
	local glow = table.clone(plan)
	glow.Material = Enum.Material.Neon
	return glow
end

local function join(...: { PartPlan }): { PartPlan }
	local joined = {}
	for _, plans in { ... } do
		for _, plan in plans do
			table.insert(joined, plan)
		end
	end
	return joined
end

--[[
	A pointed animal ear from two wedges back to back, standing on base and
	leaning out to the side by tilt radians. Mirror it for the other ear.
]]
local function pointedEar(color: Color3, base: Vector3, size: Vector2, tilt: number): { PartPlan }
	local frame = CFrame.new(base) * CFrame.Angles(0, 0, tilt)
	local halfSize = Vector3.new(0.12, size.Y, size.X / 2)
	return {
		{
			Shape = "Wedge",
			Size = halfSize,
			Offset = frame
				* CFrame.new(-size.X / 4, size.Y / 2, 0)
				* CFrame.Angles(0, math.pi / 2, 0),
			Color = color,
		},
		{
			Shape = "Wedge",
			Size = halfSize,
			Offset = frame
				* CFrame.new(size.X / 4, size.Y / 2, 0)
				* CFrame.Angles(0, -math.pi / 2, 0),
			Color = color,
		},
	}
end

local function hairCap(color: Color3): PartPlan
	return {
		Shape = "Ellipsoid",
		Size = HAIR_CAP_SIZE,
		Offset = HAIR_CAP_OFFSET,
		Color = color,
	}
end

local function belt(color: Color3): PartPlan
	return {
		Shape = "Block",
		Size = Vector3.new(1.56, 0.22, 0.86),
		Offset = CFrame.new(0, -0.62, 0),
		Color = color,
	}
end

--[[
	A sword held in the hand, pointing ahead of the fist.
]]
local function handBlade(options: BladeOptions): { PartPlan }
	local length = options.Length
	local bend = options.Bend or 0
	local straightLength = if bend > 0 then length - BEND_LENGTH else length
	local bladeColor = options.BladeColor or STEEL
	local plans: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.14, 0.14, 0.45),
			Offset = CFrame.new(0, -0.9, -0.15),
			Color = GRIP_COLOR,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.4, 0.08, 0.1),
			Offset = CFrame.new(0, -0.9, -0.42),
			Color = options.GuardColor,
			Material = Enum.Material.Metal,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.06, 0.2, straightLength),
			Offset = CFrame.new(0, -0.9, -0.45 - straightLength / 2),
			Color = bladeColor,
			Material = Enum.Material.Metal,
		},
	}
	if bend > 0 then
		local bendStart = CFrame.new(0, -0.9, -0.45 - straightLength) * CFrame.Angles(bend, 0, 0)
		table.insert(plans, {
			Shape = "Block",
			Size = Vector3.new(0.06, 0.18, BEND_LENGTH),
			Offset = bendStart * CFrame.new(0, 0, -BEND_LENGTH / 2),
			Color = bladeColor,
			Material = Enum.Material.Metal,
		})
	end
	local edgeColor = options.EdgeColor
	if edgeColor then
		table.insert(plans, {
			Shape = "Block",
			Size = Vector3.new(0.08, 0.05, straightLength - 0.05),
			Offset = CFrame.new(0, -0.79, -0.45 - straightLength / 2),
			Color = edgeColor,
			Material = Enum.Material.Neon,
		})
	end
	return plans
end

-- The Echo Ninja: a high ponytail, a mask over the lower face, an orange
-- scarf, a sword across the back, and a short blade in hand.
local function haru(): RigSpec
	local hair = Color3.fromRGB(52, 58, 104)
	local cloth = Color3.fromRGB(62, 64, 84)
	local orange = Color3.fromRGB(255, 150, 40)
	local wrap = Color3.fromRGB(215, 215, 225)
	local sideLock =
		lock(hair, Vector3.new(-0.72, 0.36, -0.06), Vector3.new(-0.74, -0.42, -0.36), 0.34)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.36, 0.72, -0.36), Vector3.new(-0.46, 0.24, -0.82), 0.36),
		lock(hair, Vector3.new(0, 0.74, -0.38), Vector3.new(0.02, 0.19, -0.86), 0.38),
		lock(hair, Vector3.new(0.36, 0.72, -0.36), Vector3.new(0.48, 0.26, -0.82), 0.36),
		sideLock,
		mirrored(sideLock),
		{
			Shape = "Cylinder",
			Size = Vector3.new(0.36, 0.24, 0.36),
			Offset = CFrame.new(0, 0.84, 0.6) * CFrame.Angles(1.2, 0, 0),
			Color = orange,
		},
		lock(hair, Vector3.new(0, 0.86, 0.66), Vector3.new(0, 0.72, 1.74), 0.48),
		lock(hair, Vector3.new(0, 0.74, 1.56), Vector3.new(0, -0.18, 1.92), 0.38),
		-- The mask covers the face below the eyes.
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.57, 0.74, 1.51),
			Offset = CFrame.new(0, -0.4, 0),
			Color = cloth,
		},
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(1.3, 0.85, 0.1),
			Offset = CFrame.new(0, 0.15, -0.42),
			Color = Color3.fromRGB(66, 66, 84),
		},
		belt(Color3.fromRGB(200, 110, 30)),
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.3, 0.42, 1.05),
			Offset = CFrame.new(0, 0.85, 0),
			Color = orange,
			Material = Enum.Material.Fabric,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.32, 1.4, 0.08),
			Offset = CFrame.new(0.35, 0.25, 0.48) * CFrame.Angles(0.35, 0, -0.15),
			Color = orange,
			Material = Enum.Material.Fabric,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.18, 2.3, 0.2),
			Offset = CFrame.new(0, 0.1, 0.52) * CFrame.Angles(0, 0, 0.7),
			Color = Color3.fromRGB(25, 25, 30),
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.16, 0.65, 0.16),
			Offset = CFrame.new(-0.95, 1.21, 0.52) * CFrame.Angles(0, 0, 0.7),
			Color = orange,
		},
	}
	local wristWrap: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.54, 0.32, 0.54),
		Offset = CFrame.new(0, -0.5, 0),
		Color = wrap,
	}
	local shinWrap: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.64, 0.6, 0.64),
		Offset = CFrame.new(0, -0.55, 0),
		Color = wrap,
	}
	return {
		SkinColor = Color3.fromRGB(255, 224, 196),
		HairColor = hair,
		EyeColor = Color3.fromRGB(235, 140, 35),
		TopColor = cloth,
		BottomColor = Color3.fromRGB(52, 52, 66),
		ShoeColor = Color3.fromRGB(28, 28, 34),
		AttackMotion = "Slash",
		Attachments = {
			Head = head,
			Torso = torso,
			LeftArm = { wristWrap },
			RightArm = join({ wristWrap }, handBlade({ Length = 1, GuardColor = orange })),
			LeftLeg = { shinWrap },
			RightLeg = { shinWrap },
		},
	}
end

-- The Limit Breaker: white twin tails with glowing tips, a gold-trimmed
-- jacket, ki gauntlets, and a ki orb charging in hand.
local function ryuka(): RigSpec
	local hair = Color3.fromRGB(238, 238, 248)
	local gold = Color3.fromRGB(240, 196, 48)
	local glow = Color3.fromRGB(255, 215, 60)
	local dark = Color3.fromRGB(40, 40, 56)
	local jacket = Color3.fromRGB(240, 240, 234)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.36, 0.72, -0.36), Vector3.new(-0.5, 0.22, -0.82), 0.36),
		lock(hair, Vector3.new(0, 0.74, -0.38), Vector3.new(-0.05, 0.17, -0.86), 0.38),
		lock(hair, Vector3.new(0.36, 0.72, -0.36), Vector3.new(0.5, 0.22, -0.82), 0.36),
		lock(hair, Vector3.new(0, 0.88, 0), Vector3.new(-0.15, 1.45, -0.3), 0.16),
	}
	local twinTail: { PartPlan } = {
		lock(hair, Vector3.new(-0.66, 0.5, 0.3), Vector3.new(-1.3, 0.05, 0.62), 0.55),
		lock(hair, Vector3.new(-1.25, 0.12, 0.6), Vector3.new(-1.4, -0.9, 0.66), 0.48),
		glowing(lock(glow, Vector3.new(-1.38, -0.8, 0.66), Vector3.new(-1.42, -1.45, 0.68), 0.36)),
		{
			Shape = "Ball",
			Size = Vector3.one * 0.3,
			Offset = CFrame.new(-0.7, 0.5, 0.3),
			Color = glow,
			Material = Enum.Material.Neon,
		},
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(1.3, 0.35, 0.95),
			Offset = CFrame.new(0, 0.9, 0.02),
			Color = gold,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.14, 1.6, 0.06),
			Offset = CFrame.new(0, 0, -0.42),
			Color = glow,
			Material = Enum.Material.Neon,
		},
		belt(dark),
	}
	local coatTail: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.7, 0.8, 0.08),
		Offset = CFrame.new(-0.38, -1.1, 0.4) * CFrame.Angles(0.15, 0, 0),
		Color = jacket,
	}
	local gauntlet: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.6, 0.75, 0.6),
			Offset = CFrame.new(0, -0.5, 0),
			Color = gold,
			Material = Enum.Material.Metal,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.64, 0.1, 0.64),
			Offset = CFrame.new(0, -0.15, 0),
			Color = glow,
			Material = Enum.Material.Neon,
		},
	}
	local kiOrb: PartPlan = {
		Shape = "Ball",
		Size = Vector3.one * 0.42,
		Offset = CFrame.new(0, -1.05, -0.28),
		Color = glow,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	}
	return {
		SkinColor = Color3.fromRGB(250, 222, 195),
		HairColor = hair,
		EyeColor = Color3.fromRGB(255, 186, 30),
		TopColor = jacket,
		BottomColor = dark,
		ShoeColor = gold,
		AttackMotion = "Shoot",
		Attachments = {
			Head = join(head, withMirrors(twinTail)),
			Torso = join(torso, withMirrors({ coatTail })),
			LeftArm = gauntlet,
			RightArm = join(gauntlet, { kiOrb }),
		},
	}
end

-- The Oathless: shaggy hair, an eyepatch, a fur-collared leather coat with
-- long tails, a steel pauldron, and a curved blade in each hand.
local function torvik(): RigSpec
	local hair = Color3.fromRGB(72, 46, 36)
	local coat = Color3.fromRGB(150, 110, 80)
	local leather = Color3.fromRGB(70, 48, 36)
	local boot = Color3.fromRGB(40, 30, 25)
	local black = Color3.fromRGB(20, 18, 20)
	local brass = Color3.fromRGB(190, 150, 80)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.42, 0.66, 0.36), Vector3.new(-0.72, 0.72, 1.26), 0.43),
		lock(hair, Vector3.new(0, 0.78, 0.36), Vector3.new(0, 0.9, 1.38), 0.48),
		lock(hair, Vector3.new(0.42, 0.66, 0.36), Vector3.new(0.72, 0.66, 1.26), 0.43),
		lock(hair, Vector3.new(0, 0.36, 0.6), Vector3.new(0, -0.3, 1.2), 0.46),
		lock(hair, Vector3.new(-0.2, 0.8, 0), Vector3.new(-0.35, 1.3, 0.2), 0.36),
		lock(hair, Vector3.new(0.25, 0.8, 0.05), Vector3.new(0.45, 1.25, 0.25), 0.34),
		lock(hair, Vector3.new(-0.3, 0.72, -0.36), Vector3.new(-0.54, 0.24, -0.82), 0.36),
		lock(hair, Vector3.new(0.18, 0.74, -0.38), Vector3.new(0.36, 0.18, -0.84), 0.36),
		-- Over the left eye, turned with the face like the eye beneath.
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(0.42, 0.48, 0.16),
			Offset = CFrame.new(-0.27, -0.06, -0.7) * CFrame.Angles(0, 0.22, 0),
			Color = black,
		},
		lock(black, Vector3.new(-0.27, 0.12, -0.68), Vector3.new(-0.72, 0.45, -0.2), 0.08),
	}
	local torso: { PartPlan } = {
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.6, 0.45, 1.1),
			Offset = CFrame.new(0, 0.85, 0.05),
			Color = Color3.fromRGB(112, 92, 76),
			Material = Enum.Material.Fabric,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.16, 1.95, 0.06),
			Offset = CFrame.new(0, 0, -0.42) * CFrame.Angles(0, 0, 0.65),
			Color = leather,
		},
		belt(Color3.fromRGB(60, 40, 30)),
		{
			Shape = "Block",
			Size = Vector3.new(0.3, 0.25, 0.05),
			Offset = CFrame.new(0, -0.62, -0.45),
			Color = brass,
			Material = Enum.Material.Metal,
		},
	}
	local coatTail: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.72, 1.4, 0.08),
		Offset = CFrame.new(-0.38, -1.3, 0.4) * CFrame.Angles(0.12, 0, 0),
		Color = coat,
	}
	local pauldron: PartPlan = {
		Shape = "Ellipsoid",
		Size = Vector3.new(0.9, 0.55, 0.8),
		Offset = CFrame.new(0, 0.62, 0),
		Color = Color3.fromRGB(150, 150, 162),
		Material = Enum.Material.Metal,
	}
	local bracer: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.56, 0.45, 0.56),
		Offset = CFrame.new(0, -0.5, 0),
		Color = leather,
	}
	local bootTop: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.66, 0.6, 0.66),
		Offset = CFrame.new(0, -0.65, 0),
		Color = boot,
	}
	local blade = handBlade({ Length = 1.3, GuardColor = brass, Bend = 0.35 })
	return {
		SkinColor = Color3.fromRGB(228, 186, 150),
		HairColor = hair,
		EyeColor = Color3.fromRGB(215, 50, 50),
		TopColor = coat,
		BottomColor = Color3.fromRGB(55, 45, 40),
		ShoeColor = boot,
		AttackMotion = "DualSlash",
		Attachments = {
			Head = head,
			Torso = join(torso, withMirrors({ coatTail })),
			LeftArm = join({ pauldron, bracer }, blade),
			RightArm = join({ bracer }, blade),
			LeftLeg = { bootTop },
			RightLeg = { bootTop },
		},
	}
end

-- The Shadow Sovereign: violet hair swept back under a glowing crown, a
-- hooded mantle with long tails, shadow wisps at the shoulders, and a black
-- blade with a violet edge.
local function seoDan(): RigSpec
	local hair = Color3.fromRGB(110, 66, 190)
	local violet = Color3.fromRGB(175, 120, 255)
	local mantle = Color3.fromRGB(46, 40, 66)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(0, 0.8, -0.3), Vector3.new(0, 1.02, 1.14), 0.41),
		lock(hair, Vector3.new(0.2, 0.72, -0.4), Vector3.new(0.3, 0.1, -0.86), 0.22),
		glowing(lock(violet, Vector3.new(0, 0.5, -0.74), Vector3.new(0, 0.95, -0.82), 0.14)),
	}
	local headSides: { PartPlan } = {
		lock(hair, Vector3.new(-0.36, 0.72, -0.24), Vector3.new(-0.54, 0.9, 1.08), 0.38),
		lock(hair, Vector3.new(-0.6, 0.36, 0.24), Vector3.new(-0.72, -0.12, 1.14), 0.36),
		glowing(lock(violet, Vector3.new(-0.3, 0.48, -0.7), Vector3.new(-0.4, 0.8, -0.76), 0.1)),
	}
	local torso: { PartPlan } = {
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(2, 0.55, 1.15),
			Offset = CFrame.new(0, 0.72, 0.05),
			Color = mantle,
			Material = Enum.Material.Fabric,
		},
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.3, 0.6, 0.75),
			Offset = CFrame.new(0, 0.95, 0.5),
			Color = mantle,
			Material = Enum.Material.Fabric,
		},
		belt(Color3.fromRGB(110, 80, 200)),
	}
	local torsoSides: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.12, 1.6, 0.06),
			Offset = CFrame.new(-0.3, 0, -0.42),
			Color = violet,
			Material = Enum.Material.Neon,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.72, 1.7, 0.08),
			Offset = CFrame.new(-0.38, -1.5, 0.4) * CFrame.Angles(0.1, 0, 0),
			Color = mantle,
			Material = Enum.Material.Fabric,
		},
		{
			Shape = "Ball",
			Size = Vector3.one * 0.32,
			Offset = CFrame.new(-1, 1.1, 0.25),
			Color = violet,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		},
	}
	return {
		SkinColor = Color3.fromRGB(240, 220, 205),
		HairColor = hair,
		EyeColor = Color3.fromRGB(190, 140, 255),
		TopColor = mantle,
		BottomColor = Color3.fromRGB(28, 26, 38),
		ShoeColor = Color3.fromRGB(18, 16, 24),
		AttackMotion = "Slash",
		Attachments = {
			Head = join(head, withMirrors(headSides)),
			Torso = join(torso, withMirrors(torsoSides)),
			RightArm = handBlade({
				Length = 1.8,
				GuardColor = violet,
				BladeColor = Color3.fromRGB(20, 18, 28),
				EdgeColor = violet,
			}),
		},
	}
end

-- The Wallbreaker: a red mohawk, a heavy build, an open vest, and fists and
-- a pauldron of stone with glowing seams.
local function brakk(): RigSpec
	local hair = Color3.fromRGB(205, 62, 45)
	local skin = Color3.fromRGB(196, 142, 102)
	local stone = Color3.fromRGB(128, 118, 108)
	local ember = Color3.fromRGB(255, 140, 50)
	local head: { PartPlan } = {
		lock(hair, Vector3.new(0, 0.72, -0.42), Vector3.new(0, 1.25, -0.6), 0.36),
		lock(hair, Vector3.new(0, 0.8, -0.1), Vector3.new(0, 1.4, -0.15), 0.4),
		lock(hair, Vector3.new(0, 0.78, 0.25), Vector3.new(0, 1.38, 0.4), 0.4),
		lock(hair, Vector3.new(0, 0.62, 0.55), Vector3.new(0, 1.05, 1), 0.36),
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.6, 1.2, 0.06),
			Offset = CFrame.new(0, 0.2, -0.41),
			Color = skin,
		},
		{
			Shape = "Block",
			Size = Vector3.new(1.6, 0.38, 0.9),
			Offset = CFrame.new(0, -0.6, 0),
			Color = Color3.fromRGB(90, 60, 40),
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.48, 0.38, 0.08),
			Offset = CFrame.new(0, -0.6, -0.47),
			Color = stone,
			Material = Enum.Material.Slate,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.3, 0.06, 0.1),
			Offset = CFrame.new(0, -0.6, -0.5),
			Color = ember,
			Material = Enum.Material.Neon,
		},
	}
	local stoneFist: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.56, 0.3, 0.56),
			Offset = CFrame.new(0, -0.35, 0),
			Color = Color3.fromRGB(70, 50, 38),
		},
		-- Brakk's build widens these by a third.
		{
			Shape = "Block",
			Size = Vector3.new(0.72, 0.85, 0.72),
			Offset = CFrame.new(0, -0.88, -0.05),
			Color = stone,
			Material = Enum.Material.Slate,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.74, 0.07, 0.74),
			Offset = CFrame.new(0, -0.78, -0.05),
			Color = ember,
			Material = Enum.Material.Neon,
		},
	}
	local pauldron: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.85, 0.55, 0.8),
		Offset = CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, -0.2),
		Color = stone,
		Material = Enum.Material.Slate,
	}
	return {
		Scale = 1.1,
		Build = 1.35,
		SkinColor = skin,
		HairColor = hair,
		EyeColor = Color3.fromRGB(255, 170, 60),
		TopColor = Color3.fromRGB(150, 52, 40),
		ArmColor = skin,
		BottomColor = Color3.fromRGB(92, 72, 56),
		ShoeColor = Color3.fromRGB(60, 45, 35),
		AttackMotion = "Punch",
		Attachments = {
			Head = head,
			Torso = torso,
			LeftArm = join({ pauldron }, stoneFist),
			RightArm = stoneFist,
		},
	}
end

-- The Crimson Lancer: a long crimson braid tied with a gold ribbon, a red
-- breastplate over white, a gold sash, wide dark trousers, and a long spear.
local function akane(): RigSpec
	local hair = Color3.fromRGB(196, 36, 52)
	local crimson = Color3.fromRGB(178, 34, 46)
	local gold = Color3.fromRGB(232, 182, 62)
	local trousers = Color3.fromRGB(40, 40, 62)
	local sideLock =
		lock(hair, Vector3.new(-0.72, 0.36, -0.1), Vector3.new(-0.76, -0.55, -0.4), 0.32)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.3, 0.74, -0.38), Vector3.new(-0.5, 0.24, -0.84), 0.38),
		lock(hair, Vector3.new(0.1, 0.76, -0.4), Vector3.new(0.18, 0.2, -0.86), 0.36),
		lock(hair, Vector3.new(0.4, 0.7, -0.34), Vector3.new(0.56, 0.3, -0.8), 0.3),
		sideLock,
		mirrored(sideLock),
		lock(hair, Vector3.new(0, 0.2, 0.62), Vector3.new(0, -0.55, 0.85), 0.44),
		lock(hair, Vector3.new(0, -0.5, 0.85), Vector3.new(0, -1.25, 0.95), 0.38),
		lock(hair, Vector3.new(0, -1.2, 0.95), Vector3.new(0, -1.85, 1), 0.3),
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(0.5, 0.26, 0.26),
			Offset = CFrame.new(0, -1.8, 1),
			Color = gold,
		},
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(1.4, 0.95, 0.12),
			Offset = CFrame.new(0, 0.22, -0.43),
			Color = crimson,
			Material = Enum.Material.Metal,
		},
		belt(gold),
		{
			Shape = "Block",
			Size = Vector3.new(0.16, 0.5, 0.06),
			Offset = CFrame.new(0.35, -0.9, -0.44),
			Color = gold,
		},
	}
	local shoulderGuard: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.85, 0.45, 0.8),
		Offset = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, -0.25),
		Color = crimson,
		Material = Enum.Material.Metal,
	}
	local spear: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.12, 0.12, 4.2),
			Offset = CFrame.new(0, -0.9, -1),
			Color = Color3.fromRGB(92, 56, 36),
		},
		lock(STEEL, Vector3.new(0, -0.9, -3.05), Vector3.new(0, -0.9, -3.75), 0.24),
		{
			Shape = "Ball",
			Size = Vector3.one * 0.26,
			Offset = CFrame.new(0, -0.9, -3.02),
			Color = crimson,
		},
	}
	local hakama: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.74, 1.5, 0.76),
		Offset = CFrame.new(0, 0.2, 0),
		Color = trousers,
	}
	return {
		SkinColor = Color3.fromRGB(250, 220, 200),
		HairColor = hair,
		EyeColor = Color3.fromRGB(255, 186, 60),
		TopColor = Color3.fromRGB(240, 236, 230),
		BottomColor = trousers,
		ShoeColor = Color3.fromRGB(30, 28, 34),
		AttackMotion = "Punch",
		Attachments = {
			Head = head,
			Torso = torso,
			LeftArm = { shoulderGuard },
			RightArm = spear,
			LeftLeg = { hakama },
			RightLeg = { hakama },
		},
	}
end

-- The Storm Fox: sky-blue hair with fox ears, a big fox tail with a white
-- tip, a short blue jacket trimmed in light, and glowing claws on both hands.
local function rin(): RigSpec
	local hair = Color3.fromRGB(130, 205, 255)
	local spark = Color3.fromRGB(120, 230, 255)
	local jacket = Color3.fromRGB(40, 64, 150)
	local earTip = Color3.fromRGB(40, 60, 110)
	local ears = join(
		pointedEar(hair, Vector3.new(-0.45, 0.78, 0.05), Vector2.new(0.5, 0.62), 0.3),
		pointedEar(earTip, Vector3.new(-0.45, 0.84, -0.03), Vector2.new(0.28, 0.4), 0.3)
	)
	local sideLock =
		lock(hair, Vector3.new(-0.72, 0.36, -0.08), Vector3.new(-0.74, -0.4, -0.36), 0.32)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.34, 0.72, -0.36), Vector3.new(-0.5, 0.26, -0.84), 0.36),
		lock(hair, Vector3.new(0.02, 0.76, -0.4), Vector3.new(0.06, 0.2, -0.86), 0.36),
		lock(hair, Vector3.new(0.36, 0.72, -0.36), Vector3.new(0.52, 0.26, -0.84), 0.34),
		lock(hair, Vector3.new(0, 0.5, 0.55), Vector3.new(0, -0.2, 0.95), 0.5),
	}
	local torso: { PartPlan } = {
		belt(Color3.fromRGB(24, 30, 60)),
		{
			Shape = "Block",
			Size = Vector3.new(0.1, 1.5, 0.06),
			Offset = CFrame.new(-0.2, 0.05, -0.42) * CFrame.Angles(0, 0, -0.35),
			Color = spark,
			Material = Enum.Material.Neon,
		},
		lock(hair, Vector3.new(0, -0.7, 0.45), Vector3.new(0, -0.35, 1.6), 0.9),
		lock(hair, Vector3.new(0, -0.45, 1.45), Vector3.new(0, 0.35, 2.15), 0.8),
		lock(Color3.new(1, 1, 1), Vector3.new(0, 0.2, 2.05), Vector3.new(0, 0.8, 2.4), 0.6),
	}
	local claws: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.6, 0.12, 0.6),
			Offset = CFrame.new(0, -0.55, 0),
			Color = spark,
			Material = Enum.Material.Neon,
		},
	}
	for _, across in { -0.16, 0, 0.16 } do
		table.insert(claws, {
			Shape = "Block",
			Size = Vector3.new(0.06, 0.08, 0.7),
			Offset = CFrame.new(across, -0.95, -0.45),
			Color = spark,
			Material = Enum.Material.Neon,
		})
	end
	return {
		SkinColor = Color3.fromRGB(252, 226, 206),
		HairColor = hair,
		EyeColor = Color3.fromRGB(255, 196, 70),
		TopColor = jacket,
		BottomColor = Color3.fromRGB(28, 32, 54),
		ShoeColor = Color3.fromRGB(22, 24, 40),
		AttackMotion = "DualSlash",
		Attachments = {
			Head = join(head, withMirrors(join(ears, { sideLock }))),
			Torso = torso,
			LeftArm = claws,
			RightArm = claws,
		},
	}
end

-- The Frost Witch: a wide witch hat with a drooping tip and a glowing gem,
-- long pale hair down her back, a long robe trimmed in white, and a staff
-- topped with an ice crystal.
local function yuki(): RigSpec
	local hair = Color3.fromRGB(222, 228, 255)
	local hat = Color3.fromRGB(32, 42, 96)
	local robe = Color3.fromRGB(44, 64, 128)
	local trim = Color3.fromRGB(240, 244, 255)
	local ice = Color3.fromRGB(160, 225, 255)
	local sideLock = lock(hair, Vector3.new(-0.72, 0.3, -0.1), Vector3.new(-0.78, -0.9, -0.3), 0.36)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.34, 0.7, -0.38), Vector3.new(-0.48, 0.24, -0.84), 0.36),
		lock(hair, Vector3.new(0.04, 0.72, -0.4), Vector3.new(0.08, 0.18, -0.86), 0.36),
		lock(hair, Vector3.new(0.36, 0.7, -0.38), Vector3.new(0.52, 0.24, -0.84), 0.34),
		sideLock,
		mirrored(sideLock),
		lock(hair, Vector3.new(0, 0.1, 0.62), Vector3.new(0, -1.5, 0.8), 1),
		{
			Shape = "Cylinder",
			Size = Vector3.new(2.3, 0.1, 2.3),
			Offset = CFrame.new(0, 0.62, 0.04) * CFrame.Angles(-0.12, 0, 0),
			Color = hat,
		},
		lock(hat, Vector3.new(0, 2.38, 0.55), Vector3.new(0, 2.55, 1.1), 0.24),
		glowing({
			Shape = "Ball",
			Size = Vector3.one * 0.26,
			Offset = CFrame.new(0, 0.9, -0.6),
			Color = ice,
		}),
	}
	-- The hat's cone is stacked rings, narrower and leaning further back
	-- toward the top, so it comes to a point.
	for step = 0, 4 do
		local width = 1.25 - step * 0.22
		table.insert(head, {
			Shape = "Cylinder",
			Size = Vector3.new(width, 0.4, width),
			Offset = CFrame.new(0, 0.8 + step * 0.36, 0.08 + step * 0.1)
				* CFrame.Angles(-0.12 - step * 0.05, 0, 0),
			Color = hat,
		})
	end
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(1.7, 1.5, 1),
			Offset = CFrame.new(0, -1.4, 0),
			Color = robe,
			Material = Enum.Material.Fabric,
		},
		{
			Shape = "Block",
			Size = Vector3.new(1.74, 0.16, 1.04),
			Offset = CFrame.new(0, -2.1, 0),
			Color = trim,
		},
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.5, 0.36, 1),
			Offset = CFrame.new(0, 0.82, 0),
			Color = trim,
			Material = Enum.Material.Fabric,
		},
		belt(Color3.fromRGB(26, 34, 76)),
	}
	local cuff: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.58, 0.2, 0.58),
		Offset = CFrame.new(0, -0.58, 0),
		Color = trim,
	}
	local staff: { PartPlan } = {
		cuff,
		{
			Shape = "Block",
			Size = Vector3.new(0.12, 3.2, 0.12),
			Offset = CFrame.new(0, -0.4, -0.25),
			Color = Color3.fromRGB(70, 82, 120),
		},
		glowing(lock(ice, Vector3.new(0, 1.15, -0.25), Vector3.new(0, 1.8, -0.25), 0.4)),
	}
	return {
		SkinColor = Color3.fromRGB(252, 232, 222),
		HairColor = hair,
		EyeColor = Color3.fromRGB(90, 170, 255),
		TopColor = robe,
		BottomColor = Color3.fromRGB(30, 36, 70),
		ShoeColor = Color3.fromRGB(26, 30, 58),
		AttackMotion = "Shoot",
		Attachments = {
			Head = head,
			Torso = torso,
			LeftArm = { cuff },
			RightArm = staff,
		},
	}
end

-- The Gunslinger: spiky black hair with amber goggles pushed up on it, a
-- long green coat with a popped collar and tails, a holster, and a pistol.
local function kenji(): RigSpec
	local hair = Color3.fromRGB(28, 28, 34)
	local coat = Color3.fromRGB(64, 116, 86)
	local collar = Color3.fromRGB(48, 90, 66)
	local leather = Color3.fromRGB(92, 62, 40)
	local gunmetal = Color3.fromRGB(92, 98, 110)
	local head: { PartPlan } = {
		hairCap(hair),
		lock(hair, Vector3.new(-0.35, 0.7, 0.1), Vector3.new(-0.65, 1.2, 0.5), 0.4),
		lock(hair, Vector3.new(0, 0.8, 0.05), Vector3.new(0, 1.35, 0.4), 0.42),
		lock(hair, Vector3.new(0.35, 0.7, 0.1), Vector3.new(0.65, 1.2, 0.5), 0.4),
		lock(hair, Vector3.new(0, 0.5, 0.5), Vector3.new(0, 0.1, 1.2), 0.45),
		lock(hair, Vector3.new(-0.25, 0.72, -0.38), Vector3.new(-0.35, 0.25, -0.86), 0.32),
		lock(hair, Vector3.new(0.25, 0.72, -0.38), Vector3.new(0.5, 0.3, -0.84), 0.32),
	}
	local goggle: { PartPlan } = {
		{
			Shape = "Cylinder",
			Size = Vector3.new(0.44, 0.1, 0.44),
			Offset = CFrame.new(-0.22, 0.56, -0.71) * CFrame.Angles(math.pi / 2, 0, 0),
			Color = Color3.fromRGB(40, 40, 46),
			Material = Enum.Material.Metal,
		},
		glowing({
			Shape = "Cylinder",
			Size = Vector3.new(0.34, 0.1, 0.34),
			Offset = CFrame.new(-0.22, 0.56, -0.76) * CFrame.Angles(math.pi / 2, 0, 0),
			Color = Color3.fromRGB(255, 172, 44),
		}),
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.5, 1.2, 0.06),
			Offset = CFrame.new(0, 0.15, -0.42),
			Color = Color3.fromRGB(222, 216, 200),
		},
		{
			Shape = "Block",
			Size = Vector3.new(1.4, 0.42, 0.95),
			Offset = CFrame.new(0, 0.9, 0.05),
			Color = collar,
		},
		belt(leather),
		{
			Shape = "Block",
			Size = Vector3.new(0.25, 0.5, 0.35),
			Offset = CFrame.new(-0.8, -0.8, 0),
			Color = leather,
		},
	}
	local coatTail: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.75, 1.9, 0.08),
		Offset = CFrame.new(-0.38, -1.6, 0.42) * CFrame.Angles(0.1, 0, 0),
		Color = coat,
	}
	local pistol: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(0.16, 0.38, 0.2),
			Offset = CFrame.new(0, -1.02, -0.08),
			Color = Color3.fromRGB(35, 35, 40),
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.2, 0.24, 0.9),
			Offset = CFrame.new(0, -0.85, -0.42),
			Color = gunmetal,
			Material = Enum.Material.Metal,
		},
	}
	return {
		SkinColor = Color3.fromRGB(240, 208, 180),
		HairColor = hair,
		EyeColor = Color3.fromRGB(110, 140, 170),
		TopColor = coat,
		BottomColor = Color3.fromRGB(46, 46, 54),
		ShoeColor = Color3.fromRGB(72, 46, 30),
		AttackMotion = "Shoot",
		Attachments = {
			Head = join(head, withMirrors(goggle)),
			Torso = join(torso, withMirrors({ coatTail })),
			RightArm = pistol,
		},
	}
end

-- The Shrine Maiden: long black hair cut straight across the brow and tied
-- with a red bow, a white top with wide sleeves, a long red skirt, and a
-- wand hung with paper streamers.
local function mio(): RigSpec
	local hair = Color3.fromRGB(24, 20, 30)
	local white = Color3.fromRGB(246, 244, 240)
	local red = Color3.fromRGB(204, 34, 46)
	local sideLock =
		lock(hair, Vector3.new(-0.72, 0.3, -0.12), Vector3.new(-0.76, -1.3, -0.3), 0.34)
	local bowLoop: PartPlan = {
		Shape = "Ellipsoid",
		Size = Vector3.new(0.62, 0.36, 0.24),
		Offset = CFrame.new(-0.36, 0.32, 0.8) * CFrame.Angles(0, 0, 0.4),
		Color = red,
	}
	local head: { PartPlan } = {
		hairCap(hair),
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.5, 0.5, 0.5),
			Offset = CFrame.new(0, 0.5, -0.5),
			Color = hair,
		},
		lock(hair, Vector3.new(0, 0.2, 0.6), Vector3.new(0, -2.2, 0.78), 1.05),
		sideLock,
		mirrored(sideLock),
		bowLoop,
		mirrored(bowLoop),
		{
			Shape = "Ball",
			Size = Vector3.one * 0.24,
			Offset = CFrame.new(0, 0.32, 0.84),
			Color = red,
		},
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(1.7, 1.9, 1.05),
			Offset = CFrame.new(0, -1.6, 0),
			Color = red,
			Material = Enum.Material.Fabric,
		},
		belt(red),
		{
			Shape = "Block",
			Size = Vector3.new(0.5, 0.36, 0.06),
			Offset = CFrame.new(0, 0.66, -0.42) * CFrame.Angles(0, 0, math.pi / 4),
			Color = red,
		},
	}
	local sleeve: PartPlan = {
		Shape = "Block",
		Size = Vector3.new(0.82, 0.95, 0.78),
		Offset = CFrame.new(0, -0.3, 0.05),
		Color = white,
		Material = Enum.Material.Fabric,
	}
	local wand: { PartPlan } = {
		sleeve,
		{
			Shape = "Block",
			Size = Vector3.new(0.08, 1.6, 0.08),
			Offset = CFrame.new(0, -0.6, -0.25),
			Color = Color3.fromRGB(150, 110, 70),
		},
	}
	for index, roll in { 0.5, -0.5, 0.5, -0.5 } do
		local side = if index % 2 == 0 then 1 else -1
		table.insert(wand, {
			Shape = "Block",
			Size = Vector3.new(0.06, 0.26, 0.2),
			Offset = CFrame.new(side * 0.1, 0.2 - index * 0.17, -0.25) * CFrame.Angles(0, 0, roll),
			Color = white,
		})
	end
	return {
		SkinColor = Color3.fromRGB(252, 230, 214),
		HairColor = hair,
		EyeColor = Color3.fromRGB(200, 60, 80),
		TopColor = white,
		BottomColor = red,
		ShoeColor = Color3.fromRGB(240, 236, 230),
		AttackMotion = "Shoot",
		Attachments = {
			Head = head,
			Torso = torso,
			LeftArm = { sleeve },
			RightArm = wand,
		},
	}
end

-- One of Seo Dan's shadow knights: a closed helmet with a glowing visor and
-- crest, dark plate armor, and a violet-edged blade like Seo Dan's.
local function shadowKnight(): RigSpec
	local armor = Color3.fromRGB(48, 42, 74)
	local plate = Color3.fromRGB(64, 56, 96)
	local violet = Color3.fromRGB(175, 120, 255)
	local head: { PartPlan } = {
		{
			Shape = "Ellipsoid",
			Size = Vector3.new(1.66, 1.68, 1.6),
			Offset = CFrame.new(0, 0.04, 0),
			Color = plate,
			Material = Enum.Material.Metal,
		},
		{
			Shape = "Block",
			Size = Vector3.new(0.9, 0.1, 0.12),
			Offset = CFrame.new(0, 0, -0.8),
			Color = violet,
			Material = Enum.Material.Neon,
		},
		glowing(lock(violet, Vector3.new(0, 0.8, 0.1), Vector3.new(0, 1.35, 0.85), 0.2)),
	}
	local torso: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(1.56, 1, 0.86),
			Offset = CFrame.new(0, 0.25, 0),
			Color = plate,
			Material = Enum.Material.Metal,
		},
		belt(Color3.fromRGB(24, 22, 34)),
	}
	local pauldron: PartPlan = {
		Shape = "Ellipsoid",
		Size = Vector3.new(0.85, 0.55, 0.8),
		Offset = CFrame.new(0, 0.62, 0),
		Color = plate,
		Material = Enum.Material.Metal,
	}
	local blade = handBlade({
		Length = 1.8,
		GuardColor = violet,
		BladeColor = Color3.fromRGB(20, 18, 28),
		EdgeColor = violet,
	})
	return {
		SkinColor = armor,
		HairColor = armor,
		EyeColor = violet,
		TopColor = armor,
		BottomColor = Color3.fromRGB(36, 32, 54),
		ShoeColor = Color3.fromRGB(24, 22, 34),
		AttackMotion = "Slash",
		Attachments = {
			Head = head,
			Torso = torso,
			LeftArm = { pauldron },
			RightArm = join({ pauldron }, blade),
		},
	}
end

-- By unit type id. Haru's clone borrows Haru's look.
Module.Looks = {
	Haru = haru(),
	Ryuka = ryuka(),
	Torvik = torvik(),
	SeoDan = seoDan(),
	Brakk = brakk(),
	Akane = akane(),
	Rin = rin(),
	Yuki = yuki(),
	Kenji = kenji(),
	Mio = mio(),
	ShadowKnight = shadowKnight(),
} :: { [string]: RigSpec? }

return Module
