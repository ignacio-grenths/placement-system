--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const MapClientService = require("../SystemPackage/MapClientService")

-- Crashpoint Valley lies on a violet alien world where a mothership came
-- down. The ground stays mid-dark and calm so units, which carry the bright
-- team colors, read against it; teal crystals and plants carry the glow.
const TERRAIN_COLORS: { [Enum.Material]: Color3 } = {
	-- Open ground along the lanes, with paler drifts.
	[Enum.Material.Ground] = Color3.fromRGB(88, 64, 120),
	[Enum.Material.Sand] = Color3.fromRGB(128, 102, 164),
	-- Jungle soil, with patches of teal moss.
	[Enum.Material.Mud] = Color3.fromRGB(60, 45, 88),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(38, 108, 100),
	-- The floor under brush, so a patch reads from far away.
	[Enum.Material.Grass] = Color3.fromRGB(30, 150, 128),
	-- Rock walls, ridges, and the plains beyond the arena.
	[Enum.Material.Rock] = Color3.fromRGB(88, 68, 120),
	[Enum.Material.Basalt] = Color3.fromRGB(38, 30, 54),
	[Enum.Material.Slate] = Color3.fromRGB(60, 48, 86),
}
const LANE_COLOR = Color3.fromRGB(96, 84, 132)
const BLUE_SIDE_COLOR = Color3.fromRGB(90, 160, 255)
const RED_SIDE_COLOR = Color3.fromRGB(255, 100, 115)
const SIDE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = BLUE_SIDE_COLOR,
	Red = RED_SIDE_COLOR,
}
const RIVER_BED_COLOR = Color3.fromRGB(12, 46, 56)
const RIVER_ENERGY_COLOR = Color3.fromRGB(30, 200, 180)
const RIVER_BANK_COLOR = Color3.fromRGB(90, 255, 220)
-- The liquid's surface lets a little of the dark bed through.
const RIVER_ENERGY_TRANSPARENCY = 0.2
const RING_FLOOR_COLOR = Color3.fromRGB(40, 28, 66)
const RING_COLOR = Color3.fromRGB(190, 120, 255)
const BASE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = Color3.fromRGB(26, 36, 70),
	Red = Color3.fromRGB(70, 26, 44),
}
const PAD_FLOOR_COLOR = Color3.fromRGB(34, 26, 52)
const CAMP_COLORS: { [MapLayout.CampKind]: Color3 } = {
	Small = Color3.fromRGB(90, 220, 160),
	CrystalGolem = Color3.fromRGB(110, 180, 255),
	EmberBeetle = Color3.fromRGB(255, 130, 60),
	Skyray = Color3.fromRGB(120, 230, 255),
	HiveQueen = Color3.fromRGB(190, 90, 230),
}
const LAUNCH_COLOR = Color3.fromRGB(120, 255, 180)
const CRYSTAL_COLOR = Color3.fromRGB(100, 235, 220)
const CRYSTAL_CORE_COLOR = Color3.fromRGB(150, 255, 235)
const PLANT_COLORS = {
	Color3.fromRGB(36, 150, 130),
	Color3.fromRGB(26, 112, 104),
	Color3.fromRGB(110, 66, 160),
}
const STALK_COLOR = Color3.fromRGB(84, 58, 128)
const BULB_COLOR = Color3.fromRGB(130, 255, 225)
const CAP_COLORS = {
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(90, 240, 220),
}
const HULL_COLOR = Color3.fromRGB(86, 92, 110)
-- Bloom pushes orange toward yellow, so the glow starts deep.
const HULL_GLOW_COLOR = Color3.fromRGB(255, 110, 50)

-- Every client builds the same scenery from the same seed.
const SCENERY_SEED = 7331
-- Red's routes are Blue's run backward, so drawing Blue's covers every lane.
const DRAWN_ROUTES_TEAM: MapLayout.MapTeam = "Blue"

-- Studs of ground drawn past the playable square's edge.
const OUTSIDE_MARGIN = 140
-- Ground at least this far from a lane's edge and the river's bank is
-- jungle, drawn in darker soil.
const JUNGLE_LANE_GAP = 10
const JUNGLE_RIVER_GAP = 6
-- Studs the brush floor reaches past the patch's edge.
const BRUSH_FLOOR_MARGIN = 1
const LANE_EDGE_WIDTH = 0.5
const RIVER_BANK_WIDTH = 0.6
const BASE_EDGE_WIDTH = 0.8
const BASE_INNER_INSET = 8
-- Radii in studs, by camp kind.
const CAMP_RADII: { [MapLayout.CampKind]: number } = {
	Small = 6,
	CrystalGolem = 9,
	EmberBeetle = 9,
	Skyray = 18,
	HiveQueen = 26,
}
const CAMP_RING_WIDTH = 0.5
const PAD_RADIUS = 4
const LANDING_RADIUS = 3
-- Jungle walls are rock ridges this tall, low enough that the overhead
-- camera still sees units behind them.
const JUNGLE_WALL_HEIGHT = 4
-- Terrain rounds every shape out to its 4-stud cells, so the rock is drawn
-- this much thinner than the wall to keep its foot off the lanes and river.
const ROCK_INSET = 1
-- The ridge around the arena: rock mounds this far past the edge, spaced
-- along it, with radii in this range.
const RIDGE_OFFSET = 12
const RIDGE_SPACING = 8
const RIDGE_MIN_RADIUS = 8
const RIDGE_MAX_RADIUS = 13
const HILL_COUNT = 36
const CRATER_COUNT = 7
const OUTSIDE_CRYSTAL_COUNT = 14
const MUSHROOM_COUNT = 18
-- Plant blades per stud of a brush patch's length, on top of a base count.
const BLADES_PER_STUD = 1.1
const BASE_BLADES = 14
const BULBS_PER_BRUSH = 3

-- Draw order, bottom to top. Lanes bridge the river and run on into the
-- bases, under the bases' borders.
const RIVER_LAYER = 1
const RIVER_ENERGY_LAYER = 1.3
const RIVER_BANK_LAYER = 1.6
const RING_FLOOR_LAYER = 2
const BASE_LAYER = 2.2
const LANE_LAYER = 3
const LANE_EDGE_LAYER = 3.5
const RING_LAYER = 3.7
const BASE_EDGE_LAYER = 4.5
const DETAIL_LAYER = 5
const DETAIL_GLOW_LAYER = 5.3
const DETAIL_RING_LAYER = 5.6

const NEON = { Material = Enum.Material.Neon }
-- Force fields pulse, and a bright one at its peak blooms a pale haze over
-- the floor around it, so fields are dark and see-through.
const FIELD = { Material = Enum.Material.ForceField, Transparency = 0.4 }
const FIELD_DARKENING = 0.55

type PropOptions = MapClientService.PropOptions

-- A straight piece of a lane or the river, flattened to numbers so the
-- ground painter can test thousands of cells against it quickly.
type Segment = {
	AX: number,
	AZ: number,
	BX: number,
	BZ: number,
}

local Module = {}

local random = Random.new(SCENERY_SEED)

local function getPathLength(points: { Vector3 }): number
	local length = 0
	for index = 1, #points - 1 do
		length += (points[index + 1] - points[index]).Magnitude
	end
	return length
end

--[[
	Splits a path at the share of its length given, returning the part before
	and the part after.
]]
local function splitPath(points: { Vector3 }, share: number): ({ Vector3 }, { Vector3 })
	local target = getPathLength(points) * share
	local walked = 0
	local before = { points[1] }
	for index = 1, #points - 1 do
		local from = points[index]
		local to = points[index + 1]
		local length = (to - from).Magnitude
		if walked + length >= target and length > 0 then
			local middle = from + (to - from) * ((target - walked) / length)
			table.insert(before, middle)
			local after = { middle }
			table.move(points, index + 1, #points, 2, after)
			return before, after
		end
		walked += length
		table.insert(before, to)
	end
	return before, {}
end

local function removeRepeats(points: { Vector3 }): { Vector3 }
	local kept = {}
	for _, point in points do
		local last = kept[#kept]
		if not last or (point - last).Magnitude > 0.01 then
			table.insert(kept, point)
		end
	end
	return kept
end

local function getNormal(from: Vector3, to: Vector3): Vector3
	local direction = to - from
	return Vector3.new(-direction.Z, 0, direction.X).Unit
end

--[[
	Returns the path shifted sideways by distance with mitered corners, so
	edge lines drawn along it meet exactly where the path turns instead of
	crossing on the inside of the turn.
]]
local function offsetPath(points: { Vector3 }, distance: number): { Vector3 }
	local shifted = table.create(#points)
	for index, point in points do
		local before = if index > 1 then getNormal(points[index - 1], point) else nil
		local after = if index < #points then getNormal(point, points[index + 1]) else nil
		local normal = if before and after
			then (before + after).Unit
			else (before or after) :: Vector3
		-- A corner's offset point sits further out so both edges stay at
		-- distance from their own segment.
		local stretch = if before then 1 / normal:Dot(before) else 1
		table.insert(shifted, point + normal * distance * stretch)
	end
	return shifted
end

local function drawPathEdges(points: { Vector3 }, width: number, color: Color3)
	local path = removeRepeats(points)
	if #path < 2 then
		return
	end
	for _, side in { 1, -1 } do
		local edge = offsetPath(path, side * width / 2)
		for index = 1, #edge - 1 do
			MapClientService:DrawLine(
				edge[index],
				edge[index + 1],
				LANE_EDGE_WIDTH,
				color,
				LANE_EDGE_LAYER,
				NEON
			)
		end
	end
end

local function findCore(team: MapLayout.MapTeam): Vector3?
	for _, spot in MapLayout.Structures do
		if spot.Team == team and spot.Tier == "Core" then
			return spot.Position
		end
	end
	return nil
end

-- Routes start beside their core, so each road is drawn on into it.
local function getRoads(): { { Vector3 } }
	local core = findCore(DRAWN_ROUTES_TEAM)
	local roads = {}
	for _, route in MapLayout.Routes[DRAWN_ROUTES_TEAM] do
		local road = table.clone(route)
		if core then
			table.insert(road, 1, core)
		end
		table.insert(roads, road)
	end
	return roads
end

local function toSegments(points: { Vector3 }, segments: { Segment })
	for index = 1, #points - 1 do
		local from = points[index]
		local to = points[index + 1]
		table.insert(segments, { AX = from.X, AZ = from.Z, BX = to.X, BZ = to.Z })
	end
end

local function getSegmentDistance(x: number, z: number, segment: Segment): number
	local dx = segment.BX - segment.AX
	local dz = segment.BZ - segment.AZ
	local lengthSquared = dx * dx + dz * dz
	local share = if lengthSquared > 0
		then math.clamp(((x - segment.AX) * dx + (z - segment.AZ) * dz) / lengthSquared, 0, 1)
		else 0
	local offsetX = x - (segment.AX + dx * share)
	local offsetZ = z - (segment.AZ + dz * share)
	return math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
end

local function getNearestDistance(x: number, z: number, segments: { Segment }): number
	local nearest = math.huge
	for _, segment in segments do
		nearest = math.min(nearest, getSegmentDistance(x, z, segment))
	end
	return nearest
end

local function isInsideBase(x: number, z: number): boolean
	for _, base in MapLayout.Bases do
		local half = base.Size / 2
		if math.abs(x - base.Center.X) <= half and math.abs(z - base.Center.Z) <= half then
			return true
		end
	end
	return false
end

--[[
	Returns the function that picks the ground's material at each spot:
	violet dust along the lanes, dark soil and moss in the jungle, teal
	ground under brush, and dark rock past the arena's edge.
]]
local function createGroundPicker(): (x: number, z: number) -> Enum.Material
	local laneSegments: { Segment } = {}
	for _, road in getRoads() do
		toSegments(road, laneSegments)
	end
	local riverSegments: { Segment } = {}
	toSegments(MapLayout.River, riverSegments)
	local brushSegments: { Segment } = {}
	local brushRadii: { number } = {}
	for _, brush in MapLayout.Brushes do
		toSegments({ brush.From, brush.To }, brushSegments)
		table.insert(brushRadii, brush.Radius + BRUSH_FLOOR_MARGIN)
	end

	local half = MapLayout.HalfSize
	local laneReach = MapLayout.LaneWidth / 2 + JUNGLE_LANE_GAP
	local riverReach = MapLayout.RiverWidth / 2 + JUNGLE_RIVER_GAP
	return function(x: number, z: number): Enum.Material
		if math.abs(x) > half or math.abs(z) > half then
			return if math.noise(x / 46, z / 46, 0.37) > 0.12
				then Enum.Material.Slate
				else Enum.Material.Basalt
		end
		for index, segment in brushSegments do
			if getSegmentDistance(x, z, segment) <= brushRadii[index] then
				return Enum.Material.Grass
			end
		end

		local isJungle = getNearestDistance(x, z, laneSegments) > laneReach
			and getNearestDistance(x, z, riverSegments) > riverReach
			and not isInsideBase(x, z)
		if isJungle then
			return if math.noise(x / 26, z / 26, 0.71) > 0.28
				then Enum.Material.LeafyGrass
				else Enum.Material.Mud
		end
		return if math.noise(x / 50, z / 50, 0.13) > 0.15
			then Enum.Material.Sand
			else Enum.Material.Ground
	end
end

local function drawGround()
	local terrain = workspace.Terrain
	for material, color in TERRAIN_COLORS do
		terrain:SetMaterialColor(material, color)
	end
	MapClientService:PaintGround(MapLayout.HalfSize + OUTSIDE_MARGIN, createGroundPicker())
end

local function drawRiver()
	local width = MapLayout.RiverWidth
	MapClientService:DrawPath(MapLayout.River, width, RIVER_BED_COLOR, RIVER_LAYER)
	-- Glass, not ForceField: a force field's shimmer fades in and out, and a
	-- river that comes and goes reads as broken.
	MapClientService:DrawPath(MapLayout.River, width - 4, RIVER_ENERGY_COLOR, RIVER_ENERGY_LAYER, {
		Material = Enum.Material.Glass,
		Transparency = RIVER_ENERGY_TRANSPARENCY,
	})

	local from = MapLayout.River[1]
	local to = MapLayout.River[#MapLayout.River]
	local side = Vector3.new(-(to - from).Z, 0, (to - from).X).Unit * width / 2
	for _, offset in { side, -side } do
		MapClientService:DrawLine(
			from + offset,
			to + offset,
			RIVER_BANK_WIDTH,
			RIVER_BANK_COLOR,
			RIVER_BANK_LAYER,
			NEON
		)
	end
end

local function drawCrashRing()
	local ring = MapLayout.CrashRing
	MapClientService:DrawDisc(ring.Position, ring.Radius, RING_FLOOR_COLOR, RING_FLOOR_LAYER)
	MapClientService:DrawRing(ring.Position, ring.Radius, 0.8, RING_COLOR, RING_LAYER, NEON)
	MapClientService:DrawRing(ring.Position, ring.Radius * 0.66, 0.4, RING_COLOR, RING_LAYER, {
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	MapClientService:DrawRing(ring.Position, ring.Radius * 0.33, 0.4, RING_COLOR, RING_LAYER, {
		Material = Enum.Material.Neon,
		Transparency = 0.5,
	})
end

local function drawLanes()
	for _, road in getRoads() do
		MapClientService:DrawPath(road, MapLayout.LaneWidth, LANE_COLOR, LANE_LAYER, {
			Material = Enum.Material.Slate,
		})

		-- Each lane's edges glow in the color of the side that holds that half.
		local blueHalf, redHalf = splitPath(road, 0.5)
		drawPathEdges(blueHalf, MapLayout.LaneWidth, BLUE_SIDE_COLOR)
		drawPathEdges(redHalf, MapLayout.LaneWidth, RED_SIDE_COLOR)
	end
end

local function drawBases()
	for team, base in MapLayout.Bases do
		-- Annotated because luau-lsp types a loop key over string literals as string.
		local mapTeam: MapLayout.MapTeam = team :: MapLayout.MapTeam
		local sideColor = SIDE_COLORS[mapTeam]
		MapClientService:DrawSquare(base.Center, base.Size, BASE_COLORS[mapTeam], BASE_LAYER)
		MapClientService:DrawOutline(
			base.Center,
			base.Size,
			BASE_EDGE_WIDTH,
			sideColor,
			BASE_EDGE_LAYER,
			NEON
		)
		MapClientService:DrawOutline(
			base.Center,
			base.Size - BASE_INNER_INSET * 2,
			BASE_EDGE_WIDTH / 2,
			sideColor,
			BASE_EDGE_LAYER,
			{ Material = Enum.Material.Neon, Transparency = 0.5 }
		)

		local fountain = base.Fountain
		MapClientService:DrawDisc(fountain, base.FountainRadius, PAD_FLOOR_COLOR, DETAIL_LAYER)
		MapClientService:DrawDisc(
			fountain,
			base.FountainRadius - 2,
			sideColor:Lerp(Color3.new(0, 0, 0), FIELD_DARKENING),
			DETAIL_GLOW_LAYER,
			FIELD
		)
		MapClientService:DrawRing(
			fountain,
			base.FountainRadius,
			0.8,
			sideColor,
			DETAIL_RING_LAYER,
			NEON
		)
		MapClientService:DrawRing(
			fountain,
			base.FountainRadius * 0.5,
			0.4,
			sideColor,
			DETAIL_RING_LAYER,
			NEON
		)
	end
end

local function drawCamps()
	for _, camp in MapLayout.Camps do
		local radius = CAMP_RADII[camp.Kind]
		local color = CAMP_COLORS[camp.Kind]
		MapClientService:DrawDisc(camp.Position, radius, PAD_FLOOR_COLOR, DETAIL_LAYER)
		MapClientService:DrawRing(
			camp.Position,
			radius,
			CAMP_RING_WIDTH,
			color,
			DETAIL_RING_LAYER,
			NEON
		)
		if not camp.Team then
			-- The river bosses' pits get a second, inner ring.
			MapClientService:DrawRing(
				camp.Position,
				radius * 0.75,
				CAMP_RING_WIDTH,
				color,
				DETAIL_RING_LAYER,
				{ Material = Enum.Material.Neon, Transparency = 0.4 }
			)
		end
	end
end

local function drawLaunchPads()
	for _, pad in MapLayout.LaunchPads do
		MapClientService:DrawDisc(
			pad.Position,
			PAD_RADIUS,
			LAUNCH_COLOR:Lerp(Color3.new(0, 0, 0), FIELD_DARKENING),
			DETAIL_GLOW_LAYER,
			FIELD
		)
		MapClientService:DrawRing(
			pad.Position,
			PAD_RADIUS,
			0.5,
			LAUNCH_COLOR,
			DETAIL_RING_LAYER,
			NEON
		)
		MapClientService:DrawRing(
			pad.Landing,
			LANDING_RADIUS,
			0.3,
			LAUNCH_COLOR,
			DETAIL_RING_LAYER,
			{
				Material = Enum.Material.Neon,
				Transparency = 0.4,
			}
		)
		MapClientService:DrawLine(pad.Position, pad.Landing, 0.4, LAUNCH_COLOR, DETAIL_RING_LAYER, {
			Material = Enum.Material.Neon,
			Transparency = 0.75,
		})
	end
end

--[[
	A cluster of teal crystal shards leaning out from a point on the ground,
	the tallest with a glowing core.
]]
local function drawCrystals(base: Vector3, scale: number)
	local shardCount = random:NextInteger(3, 5)
	for index = 1, shardCount do
		local height = random:NextNumber(2.5, 5) * scale * (if index == 1 then 1.3 else 1)
		local width = random:NextNumber(0.7, 1.2) * scale
		local lean = CFrame.Angles(
			math.rad(random:NextNumber(-25, 25)),
			random:NextNumber(0, math.pi * 2),
			math.rad(random:NextNumber(-25, 25))
		)
		local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * scale
		local cframe = CFrame.new(base + offset) * lean * CFrame.new(0, height / 2 - 0.5, 0)
		MapClientService:DrawProp(cframe, Vector3.new(width, height, width), CRYSTAL_COLOR, {
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
		if index == 1 then
			MapClientService:DrawProp(
				cframe,
				Vector3.new(width * 0.4, height * 0.85, width * 0.4),
				CRYSTAL_CORE_COLOR,
				NEON
			)
		end
	end
end

--[[
	Draws each jungle wall as the server shapes it, a thick line with round
	ends, built as a ridge of violet rock with crystals breaking through.
]]
local function drawJungleWalls()
	local terrain = workspace.Terrain
	for _, wall in MapLayout.Walls do
		local length = (wall.To - wall.From).Magnitude
		local thickness = (wall.Radius - ROCK_INSET) * 2
		-- Sunk halfway, so the ridge rises from the ground instead of sitting
		-- on it.
		local lift = Vector3.new(0, JUNGLE_WALL_HEIGHT / 4, 0)
		local middle = wall.From:Lerp(wall.To, 0.5) + lift
		terrain:FillBlock(
			CFrame.lookAt(middle, wall.To + lift),
			Vector3.new(thickness, JUNGLE_WALL_HEIGHT * 1.5, length),
			Enum.Material.Rock
		)
		for _, point in { wall.From, wall.To } do
			terrain:FillBall(point + lift, wall.Radius, Enum.Material.Rock)
		end

		-- Crystals break out of the ridge's top.
		local top = Vector3.new(0, JUNGLE_WALL_HEIGHT - 1, 0)
		drawCrystals(wall.From:Lerp(wall.To, random:NextNumber(0.2, 0.45)) + top, 0.8)
		drawCrystals(wall.From:Lerp(wall.To, random:NextNumber(0.6, 0.85)) + top, 0.6)
	end
end

--[[
	A patch of brush: tall alien fronds in teal and violet, and a few stalks
	with glowing bulbs, all inside the patch's shape.
]]
local function drawBrush(brush: MapLayout.BrushSpot)
	local length = (brush.To - brush.From).Magnitude
	local bladeCount = math.floor(length * BLADES_PER_STUD) + BASE_BLADES
	local function pickSpot(margin: number): Vector3
		local along = brush.From:Lerp(brush.To, random:NextNumber())
		local distance = math.sqrt(random:NextNumber()) * (brush.Radius - margin)
		local angle = random:NextNumber(0, math.pi * 2)
		return along + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
	end

	for _ = 1, bladeCount do
		local height = random:NextNumber(2.6, 4.2)
		local depth = random:NextNumber(1.2, 1.8)
		local tilt = CFrame.Angles(
			math.rad(random:NextNumber(-15, 15)),
			random:NextNumber(0, math.pi * 2),
			math.rad(random:NextNumber(-15, 15))
		)
		local color = PLANT_COLORS[random:NextInteger(1, #PLANT_COLORS)]
		MapClientService:DrawProp(
			CFrame.new(pickSpot(0.5)) * tilt * CFrame.new(0, height / 2, 0),
			Vector3.new(0.25, height, depth),
			color,
			{ Shape = "Wedge" }
		)
	end
	for _ = 1, BULBS_PER_BRUSH do
		local spot = pickSpot(1.5)
		local height = random:NextNumber(3.5, 5)
		MapClientService:DrawProp(
			CFrame.new(spot + Vector3.new(0, height / 2, 0)),
			Vector3.new(0.3, height, 0.3),
			STALK_COLOR,
			{ Shape = "Cylinder" }
		)
		MapClientService:DrawProp(
			CFrame.new(spot + Vector3.new(0, height, 0)),
			Vector3.new(0.9, 0.9, 0.9),
			BULB_COLOR,
			{ Shape = "Ball", Material = Enum.Material.Neon }
		)
	end
end

local function drawBrushes()
	for _, brush in MapLayout.Brushes do
		drawBrush(brush)
	end
end

--[[
	An alien mushroom: a pale stalk under a wide glowing cap.
]]
local function drawMushroom(base: Vector3, scale: number)
	local height = random:NextNumber(2, 4) * scale
	local capWidth = random:NextNumber(2.5, 4) * scale
	local cap = CAP_COLORS[random:NextInteger(1, #CAP_COLORS)]
	MapClientService:DrawProp(
		CFrame.new(base + Vector3.new(0, height / 2, 0)),
		Vector3.new(0.7 * scale, height, 0.7 * scale),
		STALK_COLOR,
		{ Shape = "Cylinder" }
	)
	MapClientService:DrawProp(
		CFrame.new(base + Vector3.new(0, height, 0)),
		Vector3.new(capWidth, capWidth * 0.35, capWidth),
		cap,
		{ Shape = "Ball", Material = Enum.Material.Neon }
	)
end

--[[
	Returns a random spot past the arena's edge, between the ridge and the
	edge of the drawn ground.
]]
local function pickOutsideSpot(): Vector3
	local half = MapLayout.HalfSize
	local reach = random:NextNumber(half + RIDGE_OFFSET + 14, half + OUTSIDE_MARGIN - 10)
	local across = random:NextNumber(-half - OUTSIDE_MARGIN + 10, half + OUTSIDE_MARGIN - 10)
	local side = random:NextInteger(1, 4)
	if side == 1 then
		return Vector3.new(across, 0, -reach)
	elseif side == 2 then
		return Vector3.new(across, 0, reach)
	elseif side == 3 then
		return Vector3.new(-reach, 0, across)
	else
		return Vector3.new(reach, 0, across)
	end
end

--[[
	Rings the arena with a ridge of rock mounds, so its edge reads as the
	valley's rim instead of a fence.
]]
local function drawRidge()
	local terrain = workspace.Terrain
	local half = MapLayout.HalfSize
	local reach = half + RIDGE_OFFSET
	for offset = -reach, reach, RIDGE_SPACING do
		for _, center in
			{
				Vector3.new(offset, 0, -reach),
				Vector3.new(offset, 0, reach),
				Vector3.new(-reach, 0, offset),
				Vector3.new(reach, 0, offset),
			}
		do
			local radius = random:NextNumber(RIDGE_MIN_RADIUS, RIDGE_MAX_RADIUS)
			local sink = random:NextNumber(0, radius * 0.45)
			terrain:FillBall(center - Vector3.new(0, sink, 0), radius, Enum.Material.Rock)
		end
	end
	for _ = 1, OUTSIDE_CRYSTAL_COUNT // 2 do
		local along = random:NextNumber(-half, half)
		local spot = if random:NextNumber() < 0.5
			then Vector3.new(along, 4, reach * (if random:NextNumber() < 0.5 then 1 else -1))
			else Vector3.new(reach * (if random:NextNumber() < 0.5 then 1 else -1), 4, along)
		drawCrystals(spot, random:NextNumber(1.2, 1.8))
	end
end

--[[
	The plains beyond the rim: rolling hills, crater rims, crystal spires,
	and glowing mushrooms.
]]
local function drawOutskirts()
	local terrain = workspace.Terrain
	for index = 1, HILL_COUNT do
		local radius = random:NextNumber(12, 30)
		local center = pickOutsideSpot() - Vector3.new(0, radius * 0.6, 0)
		local material = if index % 3 == 0 then Enum.Material.Basalt else Enum.Material.Rock
		terrain:FillBall(center, radius, material)
	end
	for _ = 1, CRATER_COUNT do
		local center = pickOutsideSpot()
		local radius = random:NextNumber(10, 18)
		for step = 1, 12 do
			local angle = step / 12 * math.pi * 2
			local rim = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
			terrain:FillBall(
				rim - Vector3.new(0, 2, 0),
				random:NextNumber(3.5, 5),
				Enum.Material.Slate
			)
		end
	end
	for _ = 1, OUTSIDE_CRYSTAL_COUNT do
		drawCrystals(pickOutsideSpot(), random:NextNumber(1.5, 2.8))
	end
	for _ = 1, MUSHROOM_COUNT do
		drawMushroom(pickOutsideSpot(), random:NextNumber(1, 2))
	end
end

--[[
	A piece of the crashed mothership: a sunken hull wedge with a spine, two
	fins, glowing seams, and a dying engine at the back. Origin sits on the
	ground; the hull points along its -Z.
]]
local function drawWreck(origin: CFrame, scale: number)
	local metal = { Material = Enum.Material.Metal, CastsShadow = true }
	local function place(offset: CFrame, size: Vector3, color: Color3, options: PropOptions)
		MapClientService:DrawProp(origin * offset, size * scale, color, options)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, y * scale, z * scale)
	end

	place(
		at(0, 4, 0) * CFrame.Angles(math.rad(-8), 0, 0),
		Vector3.new(40, 12, 70),
		HULL_COLOR,
		{ Shape = "Wedge", Material = Enum.Material.Metal, CastsShadow = true }
	)
	place(at(0, 6, 22), Vector3.new(26, 12, 30), HULL_COLOR, metal)
	place(
		at(0, 13, 14) * CFrame.Angles(math.rad(-8), 0, 0),
		Vector3.new(4, 4, 56),
		HULL_COLOR,
		metal
	)
	place(
		at(-16, 9, 26) * CFrame.Angles(0, 0, math.rad(-35)),
		Vector3.new(2, 18, 20),
		HULL_COLOR,
		metal
	)
	place(
		at(16, 9, 26) * CFrame.Angles(0, 0, math.rad(35)),
		Vector3.new(2, 18, 20),
		HULL_COLOR,
		metal
	)
	place(
		at(0, 15.2, 14) * CFrame.Angles(math.rad(-8), 0, 0),
		Vector3.new(1, 0.4, 50),
		HULL_GLOW_COLOR,
		NEON
	)
	place(at(-13.2, 12.2, 22), Vector3.new(0.4, 0.4, 28), HULL_GLOW_COLOR, NEON)
	place(at(13.2, 12.2, 22), Vector3.new(0.4, 0.4, 28), HULL_GLOW_COLOR, NEON)
	place(
		at(0, 6, 37.2) * CFrame.Angles(math.rad(90), 0, 0),
		Vector3.new(14, 1, 14),
		HULL_GLOW_COLOR,
		{ Shape = "Cylinder", Material = Enum.Material.Neon }
	)
end

local function drawWreckage()
	local half = MapLayout.HalfSize
	-- The two corners away from the bases hold the biggest pieces; smaller
	-- debris lies along the outer edges.
	drawWreck(CFrame.new(-half - 70, 0, -half - 55) * CFrame.Angles(0, math.rad(40), 0), 1.2)
	drawWreck(CFrame.new(half + 60, 0, half + 75) * CFrame.Angles(0, math.rad(-140), 0), 1.1)
	drawWreck(CFrame.new(-half - 60, 0, 40) * CFrame.Angles(0, math.rad(100), 0), 0.55)
	drawWreck(CFrame.new(40, 0, -half - 60) * CFrame.Angles(0, math.rad(190), 0), 0.55)
	drawWreck(CFrame.new(half + 55, 0, -80) * CFrame.Angles(0, math.rad(-70), 0), 0.5)
	drawWreck(CFrame.new(-80, 0, half + 55) * CFrame.Angles(0, math.rad(20), 0), 0.5)
end

function Module:Start()
	drawGround()
	drawRiver()
	drawCrashRing()
	drawLanes()
	drawBases()
	drawCamps()
	drawLaunchPads()
	drawJungleWalls()
	drawBrushes()
	drawRidge()
	drawOutskirts()
	drawWreckage()
end

return Module
