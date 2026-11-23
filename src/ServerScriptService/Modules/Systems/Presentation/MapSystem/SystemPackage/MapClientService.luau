--!strict

const GROUND_THICKNESS = 2
-- Flat shapes are this thick (studs). Each layer's top sits LAYER_HEIGHT
-- above the one below, so overlapping shapes never flicker.
const FLAT_THICKNESS = 0.2
const LAYER_HEIGHT = 0.04
-- Longest straight piece, in studs, a drawn ring is built from.
const RING_SEGMENT_LENGTH = 5
const MIN_RING_SEGMENTS = 12

export type PropShape = "Block" | "Wedge" | "Cylinder" | "Ball"

export type SurfaceOptions = {
	-- SmoothPlastic when nil.
	Material: Enum.Material?,
	-- Zero when nil.
	Transparency: number?,
}

export type PropOptions = {
	-- Block when nil. A cylinder stands upright: Size.Y is its height and
	-- Size.X its diameter.
	Shape: PropShape?,
	Material: Enum.Material?,
	Transparency: number?,
	CastsShadow: boolean?,
}

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

local function createPart(color: Color3, options: SurfaceOptions?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = if options and options.Material
		then options.Material
		else Enum.Material.SmoothPlastic
	part.Transparency = if options and options.Transparency then options.Transparency else 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Layer 0 is the ground's surface, so layers start above 0.
local function getLayerCenterY(layer: number): number
	return layer * LAYER_HEIGHT - FLAT_THICKNESS / 2
end

--[[
	Draws the ground as a square whose top surface is at height zero.
]]
function Module:DrawGround(halfSize: number, color: Color3, options: SurfaceOptions?)
	local ground = createPart(color, options)
	ground.Name = "Ground"
	ground.Size = Vector3.new(halfSize * 2, GROUND_THICKNESS, halfSize * 2)
	ground.CFrame = CFrame.new(0, -GROUND_THICKNESS / 2, 0)
	ground.Parent = getFolder()
end

function Module:DrawDisc(
	center: Vector3,
	radius: number,
	color: Color3,
	layer: number,
	options: SurfaceOptions?
)
	local disc = createPart(color, options)
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(FLAT_THICKNESS, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(center.X, getLayerCenterY(layer), center.Z)
		* CFrame.Angles(0, 0, math.pi / 2)
	disc.Parent = getFolder()
end

function Module:DrawSquare(
	center: Vector3,
	size: number,
	color: Color3,
	layer: number,
	options: SurfaceOptions?
)
	local square = createPart(color, options)
	square.Size = Vector3.new(size, FLAT_THICKNESS, size)
	square.CFrame = CFrame.new(center.X, getLayerCenterY(layer), center.Z)
	square.Parent = getFolder()
end

--[[
	Draws a flat straight band from one point to another.
]]
function Module:DrawLine(
	from: Vector3,
	to: Vector3,
	width: number,
	color: Color3,
	layer: number,
	options: SurfaceOptions?
)
	local y = getLayerCenterY(layer)
	local start = Vector3.new(from.X, y, from.Z)
	local finish = Vector3.new(to.X, y, to.Z)
	local length = (finish - start).Magnitude
	if length <= 0 then
		return
	end

	local line = createPart(color, options)
	line.Size = Vector3.new(width, FLAT_THICKNESS, length)
	line.CFrame = CFrame.lookAt((start + finish) / 2, finish)
	line.Parent = getFolder()
end

--[[
	Draws a flat band through the points, with round joints so corners have
	no gaps.
]]
function Module:DrawPath(
	points: { Vector3 },
	width: number,
	color: Color3,
	layer: number,
	options: SurfaceOptions?
)
	for index = 1, #points - 1 do
		Module:DrawLine(points[index], points[index + 1], width, color, layer, options)
	end
	for _, point in points do
		Module:DrawDisc(point, width / 2, color, layer, options)
	end
end

--[[
	Draws a flat ring whose band is centered on radius, built from straight
	pieces short enough to read as a curve.
]]
function Module:DrawRing(
	center: Vector3,
	radius: number,
	width: number,
	color: Color3,
	layer: number,
	options: SurfaceOptions?
)
	local count = math.max(math.ceil(2 * math.pi * radius / RING_SEGMENT_LENGTH), MIN_RING_SEGMENTS)
	-- Sized to the band's outer edge, so neighboring pieces leave no gaps.
	local length = 2 * (radius + width / 2) * math.tan(math.pi / count)
	local origin = CFrame.new(center.X, getLayerCenterY(layer), center.Z)
	for index = 1, count do
		local segment = createPart(color, options)
		segment.Size = Vector3.new(length, FLAT_THICKNESS, width)
		segment.CFrame = origin
			* CFrame.Angles(0, index / count * math.pi * 2, 0)
			* CFrame.new(0, 0, -radius)
		segment.Parent = getFolder()
	end
end

--[[
	Draws the border of a square, its band centered on the square's edge.
]]
function Module:DrawOutline(
	center: Vector3,
	size: number,
	width: number,
	color: Color3,
	layer: number,
	options: SurfaceOptions?
)
	local half = size / 2
	local corners = {
		center + Vector3.new(-half, 0, -half),
		center + Vector3.new(half, 0, -half),
		center + Vector3.new(half, 0, half),
		center + Vector3.new(-half, 0, half),
	}
	for index, corner in corners do
		local nextCorner = corners[index % #corners + 1]
		local direction = (nextCorner - corner).Unit
		-- Runs past each corner by half the band, so corners close.
		local reach = direction * width / 2
		Module:DrawLine(corner - reach, nextCorner + reach, width, color, layer, options)
	end
end

--[[
	Places a solid 3D shape, such as a wall or a piece of wreckage. Props
	never block units or clicks.
]]
function Module:DrawProp(cframe: CFrame, size: Vector3, color: Color3, options: PropOptions?)
	local shape = if options and options.Shape then options.Shape else "Block"
	local prop: BasePart
	if shape == "Wedge" then
		prop = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		prop = part
	end

	prop.Anchored = true
	prop.CanCollide = false
	prop.CanQuery = false
	prop.CanTouch = false
	prop.CastShadow = options ~= nil and options.CastsShadow == true
	prop.Color = color
	prop.Material = if options and options.Material
		then options.Material
		else Enum.Material.SmoothPlastic
	prop.Transparency = if options and options.Transparency then options.Transparency else 0
	if shape == "Cylinder" then
		-- A cylinder part runs along its X axis, so it is stood upright.
		prop.Size = Vector3.new(size.Y, size.X, size.Z)
		prop.CFrame = cframe * CFrame.Angles(0, 0, math.pi / 2)
	else
		prop.Size = size
		prop.CFrame = cframe
	end
	prop.Parent = getFolder()
end

return Module
