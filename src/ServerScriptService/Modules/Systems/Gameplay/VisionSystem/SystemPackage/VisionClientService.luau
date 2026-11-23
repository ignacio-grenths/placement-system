--!strict

const AssetService = game:GetService("AssetService")
const RunService = game:GetService("RunService")

const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)

const VisionRules = require("./VisionRules")

-- Seconds between two redraws of the fog.
const REDRAW_INTERVAL = 1 / 15
-- Pixels along each side of the fog image. The image is stretched smoothly
-- over the map, so each pixel's edge blurs into its neighbors.
const RESOLUTION = 180
const BYTES_PER_PIXEL = 4
-- Rays cast around a unit near a wall to find what the wall hides.
const RAY_COUNT = 48
-- The fog sheet floats above the flat map art and below every unit.
const SHEET_HEIGHT = 0.35
const SHEET_THICKNESS = 0.05
const CANVAS_SIZE = 1024

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Brush = VisionRules.Brush
type UnitKind = UnitTypes.UnitKind
type Wall = VisionRules.Wall

export type FogOptions = {
	-- Studs from the map's center to each edge of the fogged square.
	Extent: number,
	Brushes: { Brush },
	-- Walls that block sight, as the server's vision uses them.
	Walls: { Wall },
	SightByKind: { [UnitKind]: number },
	Color: Color3,
	-- 0 for no fog, 1 for solid color.
	Opacity: number,
}

-- A run of pixels in one row, in bytes from the image's start.
type Span = {
	Offset: number,
	Length: number,
}

type Canvas = {
	Image: EditableImage,
	Gui: SurfaceGui,
	-- The image being drawn this redraw.
	Pixels: buffer,
	-- The image with fog everywhere, copied in to start each redraw.
	Fogged: buffer,
	-- By brush index: the pixels the patch covers.
	BrushSpans: { { Span } },
}

local Module = {}

local options: FogOptions? = nil
local canvas: Canvas? = nil
local redrawTimer = 0

local function toPixels(extent: number, studs: number): number
	return studs * RESOLUTION / (extent * 2)
end

--[[
	Clears the fog from every pixel whose center lies in the disc, given in
	pixel units.
]]
local function clearDisc(pixels: buffer, centerX: number, centerY: number, radius: number)
	local firstRow = math.max(math.ceil(centerY - radius - 0.5), 0)
	local lastRow = math.min(math.floor(centerY + radius - 0.5), RESOLUTION - 1)
	for row = firstRow, lastRow do
		local offsetY = row + 0.5 - centerY
		local halfWidth = math.sqrt(math.max(radius * radius - offsetY * offsetY, 0))
		local first = math.max(math.ceil(centerX - halfWidth - 0.5), 0)
		local last = math.min(math.floor(centerX + halfWidth - 0.5), RESOLUTION - 1)
		if last >= first then
			local offset = (row * RESOLUTION + first) * BYTES_PER_PIXEL
			buffer.fill(pixels, offset, 0, (last - first + 1) * BYTES_PER_PIXEL)
		end
	end
end

--[[
	Widens the span left to right to take in where the edge crosses the row
	at centerY, if it does.
]]
local function crossEdge(
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	centerY: number,
	left: number,
	right: number
): (number, number)
	if y0 == y1 or centerY < math.min(y0, y1) or centerY > math.max(y0, y1) then
		return left, right
	end
	local x = x0 + (centerY - y0) * (x1 - x0) / (y1 - y0)
	return math.min(left, x), math.max(right, x)
end

--[[
	Clears the fog from every pixel whose center lies in the triangle, given
	in pixel units.
]]
local function clearTriangle(
	pixels: buffer,
	ax: number,
	ay: number,
	bx: number,
	by: number,
	cx: number,
	cy: number
)
	local firstRow = math.max(math.ceil(math.min(ay, by, cy) - 0.5), 0)
	local lastRow = math.min(math.floor(math.max(ay, by, cy) - 0.5), RESOLUTION - 1)
	for row = firstRow, lastRow do
		local centerY = row + 0.5
		local left, right = crossEdge(ax, ay, bx, by, centerY, math.huge, -math.huge)
		left, right = crossEdge(bx, by, cx, cy, centerY, left, right)
		left, right = crossEdge(cx, cy, ax, ay, centerY, left, right)
		local first = math.max(math.ceil(left - 0.5), 0)
		local last = math.min(math.floor(right - 0.5), RESOLUTION - 1)
		if last >= first then
			local offset = (row * RESOLUTION + first) * BYTES_PER_PIXEL
			buffer.fill(pixels, offset, 0, (last - first + 1) * BYTES_PER_PIXEL)
		end
	end
end

-- The 2D cross product on the ground plane.
local function cross(a: Vector3, b: Vector3): number
	return a.X * b.Z - a.Z * b.X
end

--[[
	Returns how far along the ray it meets the circle, or nil if it misses.
	A ray starting inside the circle meets it at once.
]]
local function castAtCircle(
	origin: Vector3,
	direction: Vector3,
	center: Vector3,
	radius: number
): number?
	local offset = origin - center
	local along = offset:Dot(direction)
	local excess = offset:Dot(offset) - radius * radius
	if excess > 0 and along > 0 then
		return nil
	end
	local discriminant = along * along - excess
	if discriminant < 0 then
		return nil
	end
	return math.max(-along - math.sqrt(discriminant), 0)
end

local function castAtSegment(
	origin: Vector3,
	direction: Vector3,
	from: Vector3,
	to: Vector3
): number?
	local edge = to - from
	local denominator = cross(direction, edge)
	if math.abs(denominator) < 1e-9 then
		return nil
	end
	local toStart = from - origin
	local distance = cross(toStart, edge) / denominator
	local share = cross(toStart, direction) / denominator
	return if distance >= 0 and share >= 0 and share <= 1 then distance else nil
end

--[[
	Returns how far a ray of sight goes before a wall stops it, up to
	maxDistance. A wall is a thick line with round ends: two circles joined
	by two straight sides.
]]
local function castSight(
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
	walls: { Wall }
): number
	local nearest = maxDistance
	for _, wall in walls do
		local along = wall.To - wall.From
		local side = if along.Magnitude > 0
			then Vector3.new(-along.Z, 0, along.X).Unit * wall.Radius
			else Vector3.zero
		nearest = math.min(
			nearest,
			castAtCircle(origin, direction, wall.From, wall.Radius) or math.huge,
			castAtCircle(origin, direction, wall.To, wall.Radius) or math.huge,
			castAtSegment(origin, direction, wall.From + side, wall.To + side) or math.huge,
			castAtSegment(origin, direction, wall.From - side, wall.To - side) or math.huge
		)
	end
	return nearest
end

--[[
	Clears a viewer's sight from the fog. Near a wall, its sight is a fan of
	rays each cut short where a wall stops it; elsewhere it is a full disc.
]]
local function clearSight(pixels: buffer, current: FogOptions, position: Vector3, sight: number)
	local extent = current.Extent
	local centerX = toPixels(extent, position.X + extent)
	local centerY = toPixels(extent, position.Z + extent)
	local nearWalls = {}
	for _, wall in current.Walls do
		if VisionRules.getDistanceToWall(position, wall) <= sight + wall.Radius then
			table.insert(nearWalls, wall)
		end
	end
	if #nearWalls == 0 then
		clearDisc(pixels, centerX, centerY, toPixels(extent, sight))
		return
	end

	local previousX, previousY = 0, 0
	for index = 0, RAY_COUNT do
		local angle = index / RAY_COUNT * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local reach = castSight(position, direction, sight, nearWalls)
		local endX = toPixels(extent, position.X + direction.X * reach + extent)
		local endY = toPixels(extent, position.Z + direction.Z * reach + extent)
		if index > 0 then
			clearTriangle(pixels, centerX, centerY, previousX, previousY, endX, endY)
		end
		previousX, previousY = endX, endY
	end
end

--[[
	Returns the runs of pixels whose centers lie in the brush, scanning only
	the box around it.
]]
local function findBrushSpans(extent: number, brush: Brush): { Span }
	local single = { brush }
	local studsPerPixel = extent * 2 / RESOLUTION
	local low = brush.From:Min(brush.To) - Vector3.one * brush.Radius
	local high = brush.From:Max(brush.To) + Vector3.one * brush.Radius
	local firstColumn = math.max(math.floor((low.X + extent) / studsPerPixel), 0)
	local lastColumn = math.min(math.ceil((high.X + extent) / studsPerPixel), RESOLUTION - 1)
	local firstRow = math.max(math.floor((low.Z + extent) / studsPerPixel), 0)
	local lastRow = math.min(math.ceil((high.Z + extent) / studsPerPixel), RESOLUTION - 1)

	local spans = {}
	for row = firstRow, lastRow do
		local z = -extent + (row + 0.5) * studsPerPixel
		local runStart: number? = nil
		for column = firstColumn, lastColumn + 1 do
			local x = -extent + (column + 0.5) * studsPerPixel
			local isInside = column <= lastColumn
				and VisionRules.findBrush(single, Vector3.new(x, 0, z)) ~= nil
			if isInside and not runStart then
				runStart = column
			elseif not isInside and runStart then
				table.insert(spans, {
					Offset = (row * RESOLUTION + runStart) * BYTES_PER_PIXEL,
					Length = (column - runStart) * BYTES_PER_PIXEL,
				})
				runStart = nil
			end
		end
	end
	return spans
end

local function createFogged(current: FogOptions): buffer
	local pixelCount = RESOLUTION * RESOLUTION
	local fogged = buffer.create(pixelCount * BYTES_PER_PIXEL)
	local color = current.Color
	local alpha = math.round(math.clamp(current.Opacity, 0, 1) * 255)
	-- Little-endian, so the bytes land as red, green, blue, alpha.
	local packed = math.round(color.R * 255)
		+ math.round(color.G * 255) * 2 ^ 8
		+ math.round(color.B * 255) * 2 ^ 16
		+ alpha * 2 ^ 24
	for index = 0, pixelCount - 1 do
		buffer.writeu32(fogged, index * BYTES_PER_PIXEL, packed)
	end
	return fogged
end

local function createSheet(current: FogOptions, image: EditableImage): SurfaceGui
	local sheet = Instance.new("Part")
	sheet.Name = "FogOfWar"
	sheet.Anchored = true
	sheet.CanCollide = false
	sheet.CanQuery = false
	sheet.CanTouch = false
	sheet.CastShadow = false
	sheet.Transparency = 1
	sheet.Size = Vector3.new(current.Extent * 2, SHEET_THICKNESS, current.Extent * 2)
	-- A top-face SurfaceGui runs its columns along -Z and its rows along +X.
	-- The quarter turn lines columns up with +X and rows with +Z.
	sheet.CFrame = CFrame.new(0, SHEET_HEIGHT, 0) * CFrame.Angles(0, -math.pi / 2, 0)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(CANVAS_SIZE, CANVAS_SIZE)
	-- Fog is the same darkness in sunlight and shade.
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Parent = sheet

	local label = Instance.new("ImageLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.ImageContent = Content.fromObject(image)
	label.Parent = gui

	sheet.Parent = workspace
	return gui
end

local function createCanvas(current: FogOptions): Canvas?
	-- Fails in a published game until its Mesh / Image APIs setting is on.
	local success, result = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(RESOLUTION, RESOLUTION) })
	end)
	if not success or not result then
		warn(`Fog of war can't be drawn: {result}`)
		return nil
	end

	local brushSpans = table.create(#current.Brushes)
	for _, brush in current.Brushes do
		table.insert(brushSpans, findBrushSpans(current.Extent, brush))
	end
	local fogged = createFogged(current)
	return {
		Image = result,
		Gui = createSheet(current, result),
		Pixels = buffer.create(buffer.len(fogged)),
		Fogged = fogged,
		BrushSpans = brushSpans,
	}
end

local function redraw(current: FogOptions, target: Canvas)
	local hero = UnitClientService:GetLocalHero()
	target.Gui.Enabled = hero ~= nil
	if not hero then
		return
	end

	local pixels = target.Pixels
	buffer.copy(pixels, 0, target.Fogged)
	local renderTime = UnitClientService:GetRenderTime()
	local seenBrushes: { [number]: boolean } = {}
	for _, unit in UnitClientService:GetUnits() do
		if not unit or unit.Team ~= hero.Team or unit.IsDead then
			continue
		end
		local sight = current.SightByKind[unit.Kind]
		if not sight then
			continue
		end
		local position = UnitClientService:GetRenderPose(unit, renderTime)
		clearSight(pixels, current, position, sight)
		local brush = VisionRules.findBrush(current.Brushes, position)
		if brush then
			seenBrushes[brush] = true
		end
	end

	-- Brush nobody on the team stands in stays fogged, as the server sees it.
	for index, spans in target.BrushSpans do
		if seenBrushes[index] then
			continue
		end
		for _, span in spans do
			buffer.copy(pixels, span.Offset, target.Fogged, span.Offset, span.Length)
		end
	end

	target.Image:WritePixelsBuffer(Vector2.zero, target.Image.Size, pixels)
end

local function onHeartbeat(frameTime: number)
	redrawTimer += frameTime
	if redrawTimer < REDRAW_INTERVAL then
		return
	end
	redrawTimer = 0

	local current = options
	local target = canvas
	if current and target then
		debug.profilebegin("VisionClientService:Redraw")
		redraw(current, target)
		debug.profileend()
	end
end

--[[
	Sets what the fog covers and how it looks. Call it before Start.
]]
function Module:Configure(newOptions: FogOptions)
	options = newOptions
end

function Module:Start()
	local current = options
	if not current then
		return
	end
	canvas = createCanvas(current)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Module
