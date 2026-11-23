--!strict

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const GroundPlane = require("@game/ServerScriptService/Modules/Utilities/GroundPlane")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)

const CharacterRig = require("./CharacterRig")
const PartBuilder = require("./PartBuilder")

-- Health bar sizes in pixels, by unit kind.
const HEALTH_BAR_SIZES = {
	Hero = Vector2.new(70, 9),
	Minion = Vector2.new(34, 5),
	Monster = Vector2.new(50, 6),
	Structure = Vector2.new(110, 10),
	Summon = Vector2.new(34, 5),
	Ward = Vector2.new(24, 4),
}
const HEALTH_BAR_GAP = 1.5
const HEALTH_BAR_BACKGROUND = Color3.fromRGB(20, 20, 24)
const LOCAL_HERO_BAR_COLOR = Color3.fromRGB(90, 220, 110)
-- Fill transparency of a unit that can't be attacked yet, like an inner
-- tower whose outer tower still stands.
const UNTARGETABLE_FILL_TRANSPARENCY = 0.6
const RING_THICKNESS = 0.2
const RING_PADDING = 1.5
-- Studs units stand above the ground, clear of the map's flat markings.
const GROUND_CLEARANCE = 0.3
-- How much bigger an enlarged unit is drawn.
const ENLARGED_SCALE = 1.6
-- Radians per second of a floating unit's bob.
const BOB_SPEED = 3
const SHOT_SIZE = 0.8
const SHOT_HEIGHT = 2.5
const PICK_DISTANCE = 1000
-- Studs of slack around a unit when a click lands on the ground near it, so
-- small aliens are easy to target.
const PICK_TOLERANCE = 1.5
-- Light enough to stand out from the map's dark floor.
const METAL_COLOR = Color3.fromRGB(62, 68, 86)
const EYE_COLOR = Color3.fromRGB(235, 250, 255)
const BEAST_EYE_COLOR = Color3.fromRGB(255, 235, 170)
const BLACK = Color3.new(0, 0, 0)
const WHITE = Color3.new(1, 1, 1)
-- Studs per second past which a figure is dashing and leaves afterimages.
-- Walking tops out near 17.
const AFTERIMAGE_SPEED = 28
-- Seconds.
const AFTERIMAGE_INTERVAL = 0.035
const AFTERIMAGE_LIFETIME = 0.3
const AFTERIMAGE_TRANSPARENCY = 0.55
-- The cross a figure's melee hit leaves on its target.
const SPARK_LENGTH = 2.4
const SPARK_THICKNESS = 0.18
const SPARK_LIFETIME = 0.18
const SPARK_COLOR = Color3.fromRGB(255, 250, 220)
-- The flash where a shot lands.
const IMPACT_SIZE = 1.8
const IMPACT_LIFETIME = 0.2

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type ClientUnit = UnitClientService.ClientUnit
type Team = UnitTypes.Team

export type VisualShape = "Ball" | "Block" | "Cylinder"
-- How a unit is built: Plain is the bare shape, and Rig a walking figure
-- built from the spec's Rig, inside an unseen box of the spec's size that
-- clicks land on. The others add detail around the shape, sized from it.
export type VisualStyle = "Plain" | "Rig" | "Alien" | "Tower" | "Gate" | "Core" | "Beast"

export type VisualSpec = {
	Shape: VisualShape,
	-- Width, height, and depth in studs.
	Size: Vector3,
	-- Nil paints the unit in its team's color.
	Color: Color3?,
	-- Plain when nil.
	Style: VisualStyle?,
	HasTeamRing: boolean?,
	-- Studs the unit floats up and down. Zero when nil.
	Bob: number?,
	-- Studs per second of the unit's attack shots. Nil for melee units.
	ProjectileSpeed: number?,
	-- Of every part. Zero when nil.
	Transparency: number?,
	-- Hides the health bar, for units that can never be hit, like a clone.
	HidesHealthBar: boolean?,
	-- The figure a Rig style unit is built as.
	Rig: CharacterRig.RigSpec?,
}

type PartShape = PartBuilder.PartShape
type PartPlan = PartBuilder.PartPlan

type Visual = {
	Unit: ClientUnit,
	Body: BasePart,
	Parts: { BasePart },
	Rig: CharacterRig.Rig?,
	LastAfterimageTime: number,
	-- Each part's transparency while the unit is alive, by index in Parts.
	PartTransparencies: { number },
	HasHealthBar: boolean,
	Rotation: CFrame,
	HeightOffset: number,
	BobAmplitude: number,
	BobPhase: number,
	HealthBar: BillboardGui,
	HealthFill: Frame,
	ShownHealth: number,
	-- Dead or out of sight, and so drawn invisible.
	IsShownGone: boolean,
	IsShownTargetable: boolean,
	IsShownEnlarged: boolean,
}

type Shot = {
	Part: BasePart,
	Position: Vector3,
	TargetId: number,
	Speed: number,
}

const DEFAULT_SPEC: VisualSpec = {
	Shape = "Block",
	Size = Vector3.new(2, 2, 2),
}

local Module = {}

local specs: { [string]: VisualSpec? } = {}
local teamColors: { [Team]: Color3 } = {
	Blue = Color3.fromRGB(60, 130, 255),
	Red = Color3.fromRGB(235, 70, 70),
	Neutral = Color3.fromRGB(230, 190, 80),
}
local visuals: { [number]: Visual? } = {}
local shots: { Shot } = {}
local spareShotParts: { BasePart } = {}
local folder: Folder? = nil
local movedParts: { BasePart } = {}
local movedCFrames: { CFrame } = {}
local resizedUnits: { ClientUnit } = {}

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(BLACK, amount)
end

local function centered(shape: PartShape, size: Vector3, color: Color3): PartPlan
	return {
		Shape = shape,
		Size = size,
		Offset = CFrame.identity,
		Color = color,
	}
end

local function planRig(
	spec: VisualSpec,
	color: Color3,
	_teamColor: Color3
): (PartPlan, { PartPlan })
	local body = centered("Block", spec.Size, color)
	body.Transparency = 1
	return body, {}
end

--[[
	Where an eye sits: high on the front, so the camera, which looks from
	behind and above, still catches it over the top of a unit facing away.
	side is -1 for the left eye and 1 for the right.
]]
local function getEyeOffset(spec: VisualSpec, side: number): CFrame
	local size = spec.Size
	if spec.Shape == "Ball" then
		local radius = math.min(size.X, size.Y, size.Z) / 2
		return CFrame.new(Vector3.new(side * 0.35, 0.55, -0.75).Unit * radius * 0.92)
	end
	return CFrame.new(side * size.X * 0.22, size.Y / 2, -size.Z * 0.3)
end

--[[
	A little alien: the spec's shape in its team's color, with two glowing
	eyes and an antenna.
]]
local function planAlien(
	spec: VisualSpec,
	color: Color3,
	teamColor: Color3
): (PartPlan, { PartPlan })
	local size = spec.Size
	local eye = math.min(size.X, size.Y) * 0.3
	return centered(spec.Shape, size, color),
		{
			{
				Shape = "Ball",
				Size = Vector3.one * eye,
				Offset = getEyeOffset(spec, -1),
				Color = EYE_COLOR,
				Material = Enum.Material.Neon,
			},
			{
				Shape = "Ball",
				Size = Vector3.one * eye,
				Offset = getEyeOffset(spec, 1),
				Color = EYE_COLOR,
				Material = Enum.Material.Neon,
			},
			{
				Shape = "Cylinder",
				Size = Vector3.new(0.15, size.Y * 0.35, 0.15),
				Offset = CFrame.new(0, size.Y * 0.62, 0),
				Color = METAL_COLOR,
			},
			{
				Shape = "Ball",
				Size = Vector3.one * 0.45,
				Offset = CFrame.new(0, size.Y * 0.82, 0),
				Color = teamColor,
				Material = Enum.Material.Neon,
			},
		}
end

--[[
	A pylon: a dark column on a wide base with glowing stripes, under a
	floating crystal in its team's color.
]]
local function planTower(
	spec: VisualSpec,
	_color: Color3,
	teamColor: Color3
): (PartPlan, { PartPlan })
	local width = spec.Size.X
	local height = spec.Size.Y
	local stripe = Vector3.new(width * 0.06, height * 0.6, width * 0.06)
	local body = centered(
		"Cylinder",
		Vector3.new(width * 0.5, height * 0.8, width * 0.5),
		shade(teamColor, 0.5)
	)
	body.Material = Enum.Material.Metal
	return body,
		{
			{
				Shape = "Cylinder",
				Size = Vector3.new(width, height * 0.1, width),
				Offset = CFrame.new(0, -height * 0.45, 0),
				Color = METAL_COLOR,
				Material = Enum.Material.Metal,
			},
			{
				Shape = "Cylinder",
				Size = Vector3.new(width * 0.62, height * 0.05, width * 0.62),
				Offset = CFrame.new(0, height * 0.4, 0),
				Color = METAL_COLOR,
				Material = Enum.Material.Metal,
			},
			{
				Shape = "Block",
				Size = Vector3.one * width * 0.28,
				Offset = CFrame.new(0, height * 0.53, 0)
					* CFrame.Angles(math.rad(45), 0, math.rad(45)),
				Color = teamColor,
				Material = Enum.Material.Neon,
			},
			{
				Shape = "Block",
				Size = stripe,
				Offset = CFrame.new(0, 0, -width * 0.25),
				Color = teamColor,
				Material = Enum.Material.Neon,
			},
			{
				Shape = "Block",
				Size = stripe,
				Offset = CFrame.new(0, 0, width * 0.25),
				Color = teamColor,
				Material = Enum.Material.Neon,
			},
		}
end

--[[
	An energy gate: a shimmering field held between four capped pillars.
]]
local function planGate(
	spec: VisualSpec,
	_color: Color3,
	teamColor: Color3
): (PartPlan, { PartPlan })
	local width = spec.Size.X
	local height = spec.Size.Y
	local body = centered("Block", Vector3.new(width * 0.7, height * 0.75, width * 0.7), teamColor)
	body.Material = Enum.Material.ForceField
	local parts: { PartPlan } = {
		{
			Shape = "Block",
			Size = Vector3.new(width * 0.95, height * 0.06, width * 0.95),
			Offset = CFrame.new(0, -height * 0.47, 0),
			Color = METAL_COLOR,
			Material = Enum.Material.Metal,
		},
	}
	for _, corner in
		{ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }
	do
		local x = corner.X * width * 0.38
		local z = corner.Y * width * 0.38
		table.insert(parts, {
			Shape = "Block",
			Size = Vector3.new(width * 0.14, height, width * 0.14),
			Offset = CFrame.new(x, 0, z),
			Color = METAL_COLOR,
			Material = Enum.Material.Metal,
		})
		table.insert(parts, {
			Shape = "Block",
			Size = Vector3.new(width * 0.16, height * 0.05, width * 0.16),
			Offset = CFrame.new(x, height * 0.52, z),
			Color = teamColor,
			Material = Enum.Material.Neon,
		})
	end
	return body, parts
end

--[[
	A core: a glass sphere around a glowing heart, ringed and set on a base.
]]
local function planCore(
	spec: VisualSpec,
	_color: Color3,
	teamColor: Color3
): (PartPlan, { PartPlan })
	local size = spec.Size.X
	local body = centered("Ball", Vector3.one * size, shade(teamColor, 0.2))
	body.Material = Enum.Material.Glass
	body.Transparency = 0.4
	return body,
		{
			{
				Shape = "Ball",
				Size = Vector3.one * size * 0.45,
				Offset = CFrame.identity,
				Color = teamColor,
				Material = Enum.Material.Neon,
			},
			{
				Shape = "Cylinder",
				Size = Vector3.new(size * 1.25, 0.25, size * 1.25),
				Offset = CFrame.Angles(math.rad(12), 0, 0),
				Color = teamColor,
				Material = Enum.Material.Neon,
				Transparency = 0.5,
			},
			{
				Shape = "Cylinder",
				-- Narrower than the team ring around the core, so the ring shows.
				Size = Vector3.new(size * 0.95, size * 0.1, size * 0.95),
				Offset = CFrame.new(0, -size * 0.5, 0),
				Color = METAL_COLOR,
				Material = Enum.Material.Metal,
			},
		}
end

--[[
	A jungle monster: the spec's shape in its own color, with warm glowing
	eyes.
]]
local function planBeast(
	spec: VisualSpec,
	color: Color3,
	_teamColor: Color3
): (PartPlan, { PartPlan })
	local size = spec.Size
	local eye = math.min(size.X, size.Y) * 0.18
	return centered(spec.Shape, size, color),
		{
			{
				Shape = "Ball",
				Size = Vector3.one * eye,
				Offset = getEyeOffset(spec, -1),
				Color = BEAST_EYE_COLOR,
				Material = Enum.Material.Neon,
			},
			{
				Shape = "Ball",
				Size = Vector3.one * eye,
				Offset = getEyeOffset(spec, 1),
				Color = BEAST_EYE_COLOR,
				Material = Enum.Material.Neon,
			},
		}
end

local function planPlain(
	spec: VisualSpec,
	color: Color3,
	_teamColor: Color3
): (PartPlan, { PartPlan })
	return centered(spec.Shape, spec.Size, color), {}
end

const PLANNERS: { [VisualStyle]: (VisualSpec, Color3, Color3) -> (PartPlan, { PartPlan }) } = {
	Plain = planPlain,
	Rig = planRig,
	Alien = planAlien,
	Tower = planTower,
	Gate = planGate,
	Core = planCore,
	Beast = planBeast,
}

local function createRing(
	unit: ClientUnit,
	spec: VisualSpec,
	color: Color3,
	scale: number
): BasePart
	local diameter = (unit.Radius * 2 + RING_PADDING) * scale
	return PartBuilder.create({
		Shape = "Cylinder",
		Size = Vector3.new(diameter, RING_THICKNESS, diameter),
		Offset = CFrame.new(0, -spec.Size.Y / 2 + RING_THICKNESS / 2, 0),
		Color = color,
		Material = Enum.Material.Neon,
	}, spec.Transparency or 0)
end

local function getBarColor(unit: ClientUnit): Color3
	local localHero = UnitClientService:GetLocalHero()
	if localHero and localHero.Id == unit.Id then
		return LOCAL_HERO_BAR_COLOR
	end
	return teamColors[unit.Team]
end

local function createHealthBar(
	unit: ClientUnit,
	body: BasePart,
	spec: VisualSpec
): (BillboardGui, Frame)
	local size = HEALTH_BAR_SIZES[unit.Kind]
	local healthBar = Instance.new("BillboardGui")
	healthBar.Size = UDim2.fromOffset(size.X, size.Y)
	healthBar.StudsOffsetWorldSpace = Vector3.new(0, spec.Size.Y / 2 + HEALTH_BAR_GAP, 0)
	healthBar.AlwaysOnTop = true
	healthBar.LightInfluence = 0
	healthBar.Adornee = body

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = HEALTH_BAR_BACKGROUND
	background.BorderSizePixel = 0
	background.Parent = healthBar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = getBarColor(unit)
	fill.BorderSizePixel = 0
	fill.Parent = background

	healthBar.Parent = body
	return healthBar, fill
end

local function addVisual(unit: ClientUnit)
	local visualFolder = folder
	if not visualFolder or visuals[unit.Id] then
		return
	end

	local baseSpec = specs[unit.TypeId] or DEFAULT_SPEC
	-- An enlarged unit is the same build at a bigger size.
	local scale = if unit.IsEnlarged then ENLARGED_SCALE else 1
	local spec = table.clone(baseSpec)
	spec.Size = baseSpec.Size * scale
	local teamColor = teamColors[unit.Team]
	local color = spec.Color or teamColor
	local transparency = spec.Transparency or 0
	-- Annotated because luau-lsp widens the "Plain" default to string.
	local style: VisualStyle = spec.Style or "Plain"
	local bodyPlan, detailPlans = PLANNERS[style](spec, color, teamColor)

	local body = PartBuilder.create(bodyPlan, transparency)
	body.Name = unit.TypeId
	body:SetAttribute("UnitId", unit.Id)
	-- Details are placed around the body while it sits at the origin, so
	-- this is the turn that stands a cylinder body upright.
	local rotation = body.CFrame

	local parts: { BasePart } = { body }
	for _, plan in detailPlans do
		local part = PartBuilder.create(plan, transparency)
		PartBuilder.attach(part, body)
		table.insert(parts, part)
	end
	if spec.HasTeamRing then
		local ringColor = if spec.Style == "Beast" then color else teamColor
		local ring = createRing(unit, spec, ringColor, scale)
		PartBuilder.attach(ring, body)
		table.insert(parts, ring)
	end

	local rigSpec = spec.Rig
	local rig = if style == "Rig" and rigSpec
		then CharacterRig.build(rigSpec, transparency, scale)
		else nil
	if rig then
		-- Bones move on their own each frame, so they ride along with the
		-- body only as children, to be destroyed with it.
		for _, bone in rig.Bones do
			bone.Parent = body
		end
		for _, part in rig.Parts do
			table.insert(parts, part)
		end
	end

	local partTransparencies = table.create(#parts)
	for _, part in parts do
		table.insert(partTransparencies, part.Transparency)
	end

	local healthBar, healthFill = createHealthBar(unit, body, spec)
	local hasHealthBar = not spec.HidesHealthBar
	healthBar.Enabled = hasHealthBar

	visuals[unit.Id] = {
		Unit = unit,
		Body = body,
		Parts = parts,
		Rig = rig,
		LastAfterimageTime = 0,
		PartTransparencies = partTransparencies,
		HasHealthBar = hasHealthBar,
		Rotation = rotation,
		HeightOffset = spec.Size.Y / 2 + GROUND_CLEARANCE,
		BobAmplitude = spec.Bob or 0,
		-- Spreads the bobbing out, so a wave doesn't bounce in step.
		BobPhase = unit.Id * 1.7,
		HealthBar = healthBar,
		HealthFill = healthFill,
		ShownHealth = 1,
		IsShownGone = false,
		IsShownTargetable = true,
		IsShownEnlarged = unit.IsEnlarged,
	}
	body.Parent = visualFolder
end

local function removeVisual(unit: ClientUnit)
	local visual = visuals[unit.Id]
	if not visual then
		return
	end
	visuals[unit.Id] = nil
	visual.Body:Destroy()
end

--[[
	Hides or shows a unit that is dead or out of sight.
]]
local function showGone(visual: Visual, isGone: boolean)
	visual.IsShownGone = isGone
	for index, part in visual.Parts do
		part.Transparency = if isGone then 1 else visual.PartTransparencies[index]
	end
	visual.HealthBar.Enabled = visual.HasHealthBar and not isGone
end

local function isGone(unit: ClientUnit): boolean
	return unit.IsDead or unit.IsHidden
end

local function createShotPart(): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(SHOT_SIZE, SHOT_SIZE, SHOT_SIZE)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

--[[
	Tweens a passing effect part toward goal, then destroys it.
]]
local function fadeAway(part: BasePart, lifetime: number, goal: { [string]: any })
	local tween = TweenService:Create(
		part,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function spawnAfterimage(rig: CharacterRig.Rig, color: Color3)
	local visualFolder = folder
	if not visualFolder then
		return
	end
	for _, ghost in CharacterRig.snapshot(rig, color, AFTERIMAGE_TRANSPARENCY) do
		ghost.Parent = visualFolder
		fadeAway(ghost, AFTERIMAGE_LIFETIME, { Transparency = 1 })
	end
end

--[[
	A cross that flashes on the target of a figure's melee hit, turned to face
	the camera so it reads from any angle.
]]
local function spawnSpark(position: Vector3)
	local visualFolder = folder
	local camera = workspace.CurrentCamera
	if not visualFolder or not camera then
		return
	end
	local facing = CFrame.lookAt(position, position - camera.CFrame.LookVector)
	for _, roll in { math.pi / 4, -math.pi / 4 } do
		local part = PartBuilder.create({
			Shape = "Block",
			Size = Vector3.new(SPARK_THICKNESS, SPARK_LENGTH * 0.4, SPARK_THICKNESS),
			Offset = facing * CFrame.Angles(0, 0, roll),
			Color = SPARK_COLOR,
			Material = Enum.Material.Neon,
		}, 0)
		part.CanQuery = false
		part.Parent = visualFolder
		fadeAway(part, SPARK_LIFETIME, {
			Size = Vector3.new(SPARK_THICKNESS * 0.3, SPARK_LENGTH, SPARK_THICKNESS * 0.3),
			Transparency = 1,
		})
	end
end

local function spawnImpact(position: Vector3, color: Color3)
	local visualFolder = folder
	if not visualFolder then
		return
	end
	local part = PartBuilder.create({
		Shape = "Ball",
		Size = Vector3.one * SHOT_SIZE,
		Offset = CFrame.new(position),
		Color = color:Lerp(WHITE, 0.4),
		Material = Enum.Material.Neon,
	}, 0)
	part.CanQuery = false
	part.Parent = visualFolder
	fadeAway(part, IMPACT_LIFETIME, { Size = Vector3.one * IMPACT_SIZE, Transparency = 1 })
end

local function onAttackFired(attacker: ClientUnit, target: ClientUnit)
	local visual = visuals[attacker.Id]
	local rig = visual and visual.Rig
	local spec = specs[attacker.TypeId]
	local speed = spec and spec.ProjectileSpeed
	if rig then
		CharacterRig.startAttack(rig, os.clock())
		if not speed then
			local targetPosition =
				UnitClientService:GetRenderPose(target, UnitClientService:GetRenderTime())
			spawnSpark(targetPosition + Vector3.new(0, SHOT_HEIGHT, 0))
		end
	end

	local visualFolder = folder
	if not speed or not visualFolder then
		return
	end

	local origin = UnitClientService:GetRenderPose(attacker, UnitClientService:GetRenderTime())
	local position = origin + Vector3.new(0, SHOT_HEIGHT, 0)
	local part = table.remove(spareShotParts) or createShotPart()
	part.Color = teamColors[attacker.Team]
	part.CFrame = CFrame.new(position)
	part.Parent = visualFolder

	table.insert(shots, {
		Part = part,
		Position = position,
		TargetId = target.Id,
		Speed = speed,
	})
end

local function stepShots(deltaTime: number, renderTime: number)
	for index = #shots, 1, -1 do
		local shot = shots[index]
		local target = UnitClientService:GetUnit(shot.TargetId)
		local isFinished = true

		if target and not isGone(target) then
			local targetPosition = UnitClientService:GetRenderPose(target, renderTime)
			local offset = targetPosition + Vector3.new(0, SHOT_HEIGHT, 0) - shot.Position
			local distance = offset.Magnitude
			local stepLength = shot.Speed * deltaTime
			if distance > stepLength then
				shot.Position += offset / distance * stepLength
				shot.Part.CFrame = CFrame.new(shot.Position)
				isFinished = false
			else
				spawnImpact(targetPosition + Vector3.new(0, SHOT_HEIGHT, 0), shot.Part.Color)
			end
		end

		if isFinished then
			shot.Part.Parent = nil
			table.insert(spareShotParts, shot.Part)
			shots[index] = shots[#shots]
			shots[#shots] = nil
		end
	end
end

local function render(deltaTime: number)
	debug.profilebegin("UnitVisualsClientService:Render")
	local renderTime = UnitClientService:GetRenderTime()
	local now = os.clock()
	table.clear(movedParts)
	table.clear(movedCFrames)

	for _, visual in visuals do
		if not visual then
			continue
		end
		local unit = visual.Unit
		local isUnitGone = isGone(unit)
		if isUnitGone ~= visual.IsShownGone then
			showGone(visual, isUnitGone)
		end
		if isUnitGone then
			continue
		end

		local position, facing = UnitClientService:GetRenderPose(unit, renderTime)
		local bob = if visual.BobAmplitude > 0
			then math.sin(now * BOB_SPEED + visual.BobPhase) * visual.BobAmplitude
			else 0
		table.insert(movedParts, visual.Body)
		table.insert(
			movedCFrames,
			CFrame.new(position.X, visual.HeightOffset + bob, position.Z)
				* CFrame.Angles(0, facing, 0)
				* visual.Rotation
		)
		local rig = visual.Rig
		if rig then
			local feet = CFrame.new(position.X, GROUND_CLEARANCE + bob, position.Z)
				* CFrame.Angles(0, facing, 0)
			CharacterRig.pose(rig, feet, deltaTime, now, movedParts, movedCFrames)
			if
				rig.Speed > AFTERIMAGE_SPEED
				and now - visual.LastAfterimageTime >= AFTERIMAGE_INTERVAL
			then
				visual.LastAfterimageTime = now
				spawnAfterimage(rig, teamColors[unit.Team]:Lerp(WHITE, 0.35))
			end
		end

		local ratio = if unit.MaxHealth > 0
			then math.clamp(unit.Health / unit.MaxHealth, 0, 1)
			else 0
		if ratio ~= visual.ShownHealth then
			visual.ShownHealth = ratio
			visual.HealthFill.Size = UDim2.fromScale(ratio, 1)
		end
		if unit.IsTargetable ~= visual.IsShownTargetable then
			visual.IsShownTargetable = unit.IsTargetable
			visual.HealthFill.BackgroundTransparency = if unit.IsTargetable
				then 0
				else UNTARGETABLE_FILL_TRANSPARENCY
		end
		if unit.IsEnlarged ~= visual.IsShownEnlarged then
			table.insert(resizedUnits, unit)
		end
	end

	workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	-- A unit that grew or shrank is built again at its new size, after the
	-- loop, since rebuilding changes the table the loop walks.
	for _, unit in resizedUnits do
		removeVisual(unit)
		addVisual(unit)
	end
	table.clear(resizedUnits)
	stepShots(deltaTime, renderTime)
	debug.profileend()
end

function Module:RegisterVisual(typeId: string, spec: VisualSpec)
	specs[typeId] = spec
end

--[[
	Plays a motion on a unit drawn as a figure, such as a pose for an ability
	it cast. Units drawn any other way ignore it.
]]
function Module:PlayMotion(unitId: number, motion: CharacterRig.Motion)
	local visual = visuals[unitId]
	local rig = visual and visual.Rig
	if rig then
		CharacterRig.play(rig, motion, os.clock())
	end
end

function Module:SetTeamColor(team: Team, color: Color3)
	teamColors[team] = color
end

--[[
	Returns the live unit under a camera ray. A ray that misses every unit
	still picks one whose footprint is near where the ray meets the ground.
]]
function Module:PickUnit(ray: Ray): ClientUnit?
	local visualFolder = folder
	if not visualFolder then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { visualFolder }
	local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * PICK_DISTANCE, params)
	if result then
		local unitId = result.Instance:GetAttribute("UnitId")
		local unit = if typeof(unitId) == "number" then UnitClientService:GetUnit(unitId) else nil
		if unit and not isGone(unit) then
			return unit
		end
	end

	local groundPoint = GroundPlane.intersect(ray)
	if not groundPoint then
		return nil
	end

	local renderTime = UnitClientService:GetRenderTime()
	local nearest: ClientUnit? = nil
	local nearestDistance = math.huge
	for _, unit in UnitClientService:GetUnits() do
		if not unit or isGone(unit) then
			continue
		end
		local position = UnitClientService:GetRenderPose(unit, renderTime)
		local distance = (position - groundPoint).Magnitude - unit.Radius
		if distance <= PICK_TOLERANCE and distance < nearestDistance then
			nearest = unit
			nearestDistance = distance
		end
	end
	return nearest
end

function Module:Start()
	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "UnitVisuals"
	visualFolder.Parent = workspace
	folder = visualFolder

	UnitClientService.UnitAdded:Connect(addVisual)
	UnitClientService.UnitRemoved:Connect(removeVisual)
	UnitClientService.AttackFired:Connect(onAttackFired)
	for _, unit in UnitClientService:GetUnits() do
		if unit then
			addVisual(unit)
		end
	end

	RunService.RenderStepped:Connect(render)
end

return Module
