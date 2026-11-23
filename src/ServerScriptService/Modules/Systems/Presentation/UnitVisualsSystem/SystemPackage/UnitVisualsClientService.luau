--!strict

const RunService = game:GetService("RunService")

const GroundPlane = require("@game/ServerScriptService/Modules/Utilities/GroundPlane")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)

-- Health bar sizes in pixels, by unit kind.
const HEALTH_BAR_SIZES = {
	Hero = Vector2.new(70, 9),
	Minion = Vector2.new(34, 5),
	Monster = Vector2.new(50, 6),
	Structure = Vector2.new(110, 10),
}
const HEALTH_BAR_GAP = 1.5
const HEALTH_BAR_BACKGROUND = Color3.fromRGB(20, 20, 24)
const LOCAL_HERO_BAR_COLOR = Color3.fromRGB(90, 220, 110)
-- Fill transparency of a unit that can't be attacked yet, like an inner
-- tower whose outer tower still stands.
const UNTARGETABLE_FILL_TRANSPARENCY = 0.6
const RING_THICKNESS = 0.2
const RING_PADDING = 1.5
const SHOT_SIZE = 0.8
const SHOT_HEIGHT = 2.5
const PICK_DISTANCE = 1000
-- Studs of slack around a unit when a click lands on the ground near it, so
-- small aliens are easy to target.
const PICK_TOLERANCE = 1.5

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type ClientUnit = UnitClientService.ClientUnit
type Team = UnitTypes.Team

export type VisualShape = "Ball" | "Block" | "Cylinder"

export type VisualSpec = {
	Shape: VisualShape,
	-- Width, height, and depth in studs.
	Size: Vector3,
	-- Nil paints the unit in its team's color.
	Color: Color3?,
	HasTeamRing: boolean?,
	-- Studs per second of the unit's attack shots. Nil for melee units.
	ProjectileSpeed: number?,
	-- Of the body. Zero when nil.
	Transparency: number?,
	-- Hides the health bar, for units that can never be hit, like a clone.
	HidesHealthBar: boolean?,
}

type Visual = {
	Unit: ClientUnit,
	Body: BasePart,
	Parts: { BasePart },
	BodyTransparency: number,
	HasHealthBar: boolean,
	Rotation: CFrame,
	HeightOffset: number,
	HealthBar: BillboardGui,
	HealthFill: Frame,
	ShownHealth: number,
	IsShownDead: boolean,
	IsShownTargetable: boolean,
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

local function createBody(spec: VisualSpec, color: Color3): (BasePart, CFrame)
	local body = Instance.new("Part")
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = color
	body.Transparency = spec.Transparency or 0

	if spec.Shape == "Ball" then
		body.Shape = Enum.PartType.Ball
		body.Size = spec.Size
		return body, CFrame.identity
	elseif spec.Shape == "Cylinder" then
		-- A cylinder part runs along its X axis, so it is stood upright.
		body.Shape = Enum.PartType.Cylinder
		body.Size = Vector3.new(spec.Size.Y, spec.Size.X, spec.Size.Z)
		return body, CFrame.Angles(0, 0, math.pi / 2)
	else
		body.Size = spec.Size
		return body, CFrame.identity
	end
end

local function createTeamRing(unit: ClientUnit, body: BasePart, spec: VisualSpec): Part
	local diameter = unit.Radius * 2 + RING_PADDING
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(RING_THICKNESS, diameter, diameter)
	ring.Color = teamColors[unit.Team]
	ring.Material = Enum.Material.Neon
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Massless = true
	ring.CastShadow = false
	ring.CFrame = CFrame.new(0, -spec.Size.Y / 2 + RING_THICKNESS / 2, 0)
		* CFrame.Angles(0, 0, math.pi / 2)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = ring
	weld.Parent = ring
	ring.Parent = body
	return ring
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

	local spec = specs[unit.TypeId] or DEFAULT_SPEC
	local body, rotation = createBody(spec, spec.Color or teamColors[unit.Team])
	body.Name = unit.TypeId
	body.CFrame = rotation
	body:SetAttribute("UnitId", unit.Id)

	local parts: { BasePart } = { body }
	if spec.HasTeamRing then
		table.insert(parts, createTeamRing(unit, body, spec))
	end
	local healthBar, healthFill = createHealthBar(unit, body, spec)
	local hasHealthBar = not spec.HidesHealthBar
	healthBar.Enabled = hasHealthBar

	visuals[unit.Id] = {
		Unit = unit,
		Body = body,
		Parts = parts,
		BodyTransparency = body.Transparency,
		HasHealthBar = hasHealthBar,
		Rotation = rotation,
		HeightOffset = spec.Size.Y / 2,
		HealthBar = healthBar,
		HealthFill = healthFill,
		ShownHealth = 1,
		IsShownDead = false,
		IsShownTargetable = true,
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

local function showDead(visual: Visual, isDead: boolean)
	visual.IsShownDead = isDead
	for _, part in visual.Parts do
		part.Transparency = if isDead
			then 1
			elseif part == visual.Body then visual.BodyTransparency
			else 0
	end
	visual.HealthBar.Enabled = visual.HasHealthBar and not isDead
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

local function onAttackFired(attacker: ClientUnit, target: ClientUnit)
	local spec = specs[attacker.TypeId]
	local speed = spec and spec.ProjectileSpeed
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

		if target and not target.IsDead then
			local targetPosition = UnitClientService:GetRenderPose(target, renderTime)
			local offset = targetPosition + Vector3.new(0, SHOT_HEIGHT, 0) - shot.Position
			local distance = offset.Magnitude
			local stepLength = shot.Speed * deltaTime
			if distance > stepLength then
				shot.Position += offset / distance * stepLength
				shot.Part.CFrame = CFrame.new(shot.Position)
				isFinished = false
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
	table.clear(movedParts)
	table.clear(movedCFrames)

	for _, visual in visuals do
		if not visual then
			continue
		end
		local unit = visual.Unit
		if unit.IsDead ~= visual.IsShownDead then
			showDead(visual, unit.IsDead)
		end
		if unit.IsDead then
			continue
		end

		local position, facing = UnitClientService:GetRenderPose(unit, renderTime)
		table.insert(movedParts, visual.Body)
		table.insert(
			movedCFrames,
			CFrame.new(position.X, visual.HeightOffset, position.Z)
				* CFrame.Angles(0, facing, 0)
				* visual.Rotation
		)

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
	end

	workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	stepShots(deltaTime, renderTime)
	debug.profileend()
end

function Module:RegisterVisual(typeId: string, spec: VisualSpec)
	specs[typeId] = spec
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
		if unit and not unit.IsDead then
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
		if not unit or unit.IsDead then
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
