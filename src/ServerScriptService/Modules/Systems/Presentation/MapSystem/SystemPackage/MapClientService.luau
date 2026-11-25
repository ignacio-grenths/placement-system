--!strict

-- Flat shapes are this thick (studs). Each layer's top sits LAYER_HEIGHT
-- above the one below, so overlapping shapes never flicker.
const FLAT_THICKNESS = 0.2
const LAYER_HEIGHT = 0.04
-- Longest straight piece, in studs, a drawn ring is built from.
const RING_SEGMENT_LENGTH = 5
const MIN_RING_SEGMENTS = 12
-- Terrain is stored in cells of this many studs.
const VOXEL_SIZE = 4
-- Cells of ground painted under height zero, deep enough for the river's
-- bed.
const GROUND_LAYERS = 4
const SPRAY_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

export type PropShape = "Block" | "Wedge" | "Cylinder" | "Ball"

export type SurfaceOptions = {
	-- SmoothPlastic when nil.
	Material: Enum.Material?,
	-- Zero when nil.
	Transparency: number?,
	-- Studs the shape sits above the ground's surface, negative below it.
	-- Zero when nil.
	Elevation: number?,
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
local function getLayerCenterY(layer: number, options: SurfaceOptions?): number
	local elevation = if options and options.Elevation then options.Elevation else 0
	return layer * LAYER_HEIGHT - FLAT_THICKNESS / 2 + elevation
end

--[[
	Lays terrain over the square and asks pickGround for the material and
	surface height of each 4-stud column by its center. Heights run from 16
	studs below zero up to zero, and ground below waterLevel is flooded up to
	it. Neighboring materials blend into each other at their edges.
]]
function Module:PaintGround(
	halfSize: number,
	pickGround: (x: number, z: number) -> (Enum.Material, number),
	waterLevel: number
)
	local cellsPerSide = math.ceil(halfSize / VOXEL_SIZE) * 2
	local corner = cellsPerSide / 2 * VOXEL_SIZE
	local bottom = -VOXEL_SIZE * GROUND_LAYERS
	local region =
		Region3.new(Vector3.new(-corner, bottom, -corner), Vector3.new(corner, 0, corner))
	-- Channels are arrays indexed by x, then y, then z.
	local materials = table.create(cellsPerSide)
	local solids = table.create(cellsPerSide)
	local liquids = table.create(cellsPerSide)
	for xIndex = 1, cellsPerSide do
		local x = -corner + (xIndex - 0.5) * VOXEL_SIZE
		local materialLayers = table.create(GROUND_LAYERS)
		local solidLayers = table.create(GROUND_LAYERS)
		local liquidLayers = table.create(GROUND_LAYERS)
		for yIndex = 1, GROUND_LAYERS do
			materialLayers[yIndex] = table.create(cellsPerSide)
			solidLayers[yIndex] = table.create(cellsPerSide)
			liquidLayers[yIndex] = table.create(cellsPerSide)
		end
		for zIndex = 1, cellsPerSide do
			local material, height = pickGround(x, -corner + (zIndex - 0.5) * VOXEL_SIZE)
			for yIndex = 1, GROUND_LAYERS do
				local cellBottom = bottom + (yIndex - 1) * VOXEL_SIZE
				-- Measured in Studio: a cell filled by a share, over full
				-- cells, puts the solid surface that share of a cell above
				-- the cell's center, but water's surface that share above
				-- the cell's bottom.
				local solid = math.clamp((height - cellBottom - VOXEL_SIZE / 2) / VOXEL_SIZE, 0, 1)
				-- Water also fills the shore's columns, a little above the
				-- waterline, so terrain clips it against the slope instead of
				-- ending it in 4-stud steps.
				local water = if height < waterLevel + VOXEL_SIZE / 2
					then math.clamp((waterLevel - cellBottom) / VOXEL_SIZE, 0, 1)
					else 0
				materialLayers[yIndex][zIndex] = if solid > 0 then material else Enum.Material.Air
				solidLayers[yIndex][zIndex] = solid
				liquidLayers[yIndex][zIndex] = math.min(water, 1 - solid)
			end
		end
		materials[xIndex] = materialLayers
		solids[xIndex] = solidLayers
		liquids[xIndex] = liquidLayers
	end
	workspace.Terrain:WriteVoxelChannels(region, VOXEL_SIZE, {
		SolidMaterial = materials,
		SolidOccupancy = solids,
		LiquidOccupancy = liquids,
	})
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
	disc.CFrame = CFrame.new(center.X, getLayerCenterY(layer, options), center.Z)
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
	square.CFrame = CFrame.new(center.X, getLayerCenterY(layer, options), center.Z)
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
	local y = getLayerCenterY(layer, options)
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
	local origin = CFrame.new(center.X, getLayerCenterY(layer, options), center.Z)
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

--[[
	Puffs white spray up from a square patch, such as the foam where a
	waterfall lands.
]]
function Module:DrawSpray(center: Vector3, size: number)
	local patch = createPart(Color3.new(1, 1, 1), { Transparency = 1 })
	patch.Size = Vector3.new(size, 0.2, size)
	patch.CFrame = CFrame.new(center)

	local spray = Instance.new("ParticleEmitter")
	spray.Texture = SPRAY_TEXTURE
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.25),
		NumberSequenceKeypoint.new(1, size * 0.8),
	})
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Lifetime = NumberRange.new(1.2, 2.2)
	spray.Rate = 30
	spray.Speed = NumberRange.new(3, 7)
	spray.SpreadAngle = Vector2.new(60, 60)
	spray.Acceleration = Vector3.new(0, -3, 0)
	spray.Rotation = NumberRange.new(0, 360)
	spray.RotSpeed = NumberRange.new(-30, 30)
	spray.Parent = patch
	patch.Parent = getFolder()
end

return Module
