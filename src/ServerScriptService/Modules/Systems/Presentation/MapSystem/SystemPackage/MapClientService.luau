--!strict

const GROUND_THICKNESS = 2
-- Flat shapes are this thick (studs). Each layer's top sits LAYER_HEIGHT
-- above the one below, so overlapping shapes never flicker.
const FLAT_THICKNESS = 0.2
const LAYER_HEIGHT = 0.04

local Module = {}

local folder: Folder? = nil

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end

	local created = Instance.new("Folder")
	created.Name = "Map"
	created.Parent = workspace
	folder = created
	return created
end

local function createFlatPart(color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Layer 0 is the ground's surface, so layers start at 1.
local function getLayerCenterY(layer: number): number
	return layer * LAYER_HEIGHT - FLAT_THICKNESS / 2
end

--[[
	Draws the ground as a square whose top surface is at height zero.
]]
function Module:DrawGround(halfSize: number, color: Color3, material: Enum.Material)
	local ground = createFlatPart(color, material)
	ground.Name = "Ground"
	ground.Size = Vector3.new(halfSize * 2, GROUND_THICKNESS, halfSize * 2)
	ground.CFrame = CFrame.new(0, -GROUND_THICKNESS / 2, 0)
	ground.Parent = getFolder()
end

function Module:DrawDisc(center: Vector3, radius: number, color: Color3, layer: number)
	local disc = createFlatPart(color, Enum.Material.SmoothPlastic)
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(FLAT_THICKNESS, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(center.X, getLayerCenterY(layer), center.Z)
		* CFrame.Angles(0, 0, math.pi / 2)
	disc.Parent = getFolder()
end

function Module:DrawSquare(center: Vector3, size: number, color: Color3, layer: number)
	local square = createFlatPart(color, Enum.Material.SmoothPlastic)
	square.Size = Vector3.new(size, FLAT_THICKNESS, size)
	square.CFrame = CFrame.new(center.X, getLayerCenterY(layer), center.Z)
	square.Parent = getFolder()
end

--[[
	Draws a flat band through the points, with round joints so corners have
	no gaps.
]]
function Module:DrawPath(points: { Vector3 }, width: number, color: Color3, layer: number)
	local y = getLayerCenterY(layer)
	for index = 1, #points - 1 do
		local from = Vector3.new(points[index].X, y, points[index].Z)
		local to = Vector3.new(points[index + 1].X, y, points[index + 1].Z)
		local segment = createFlatPart(color, Enum.Material.SmoothPlastic)
		segment.Size = Vector3.new(width, FLAT_THICKNESS, (to - from).Magnitude)
		segment.CFrame = CFrame.lookAt((from + to) / 2, to)
		segment.Parent = getFolder()
	end

	for _, point in points do
		Module:DrawDisc(point, width / 2, color, layer)
	end
end

return Module
