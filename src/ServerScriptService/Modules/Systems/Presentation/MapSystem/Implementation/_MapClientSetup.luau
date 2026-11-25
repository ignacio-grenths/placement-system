--!strict

const MapGround = require("@game/ServerScriptService/Modules/Data/MapGround")
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const MapClientService = require("../SystemPackage/MapClientService")

-- Crashpoint Valley is a sunlit fantasy forest. The ground stays mid-toned
-- and calm so units, which carry the bright team colors, read against it;
-- warm dirt lanes mark where to walk and dark woods mark where you can't.
const TERRAIN_COLORS: { [Enum.Material]: Color3 } = {
	-- Open ground along the lanes, with paler meadow patches.
	[Enum.Material.Ground] = Color3.fromRGB(104, 140, 62),
	[Enum.Material.Sand] = Color3.fromRGB(138, 168, 84),
	-- Jungle soil, with patches of moss.
	[Enum.Material.Mud] = Color3.fromRGB(58, 76, 42),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(46, 104, 58),
	-- The floor under brush, so a patch reads from far away.
	[Enum.Material.Grass] = Color3.fromRGB(70, 160, 70),
	-- Stone walls, ridges, and the hills beyond the arena.
	[Enum.Material.Rock] = Color3.fromRGB(112, 108, 98),
	[Enum.Material.Basalt] = Color3.fromRGB(46, 62, 40),
	[Enum.Material.Slate] = Color3.fromRGB(86, 90, 80),
	-- Blue-gray boulders and the waterfall's cliff, along the river.
	[Enum.Material.Limestone] = Color3.fromRGB(92, 94, 104),
}
const LANE_COLOR = Color3.fromRGB(168, 132, 88)
const BLUE_SIDE_COLOR = Color3.fromRGB(90, 160, 255)
const RED_SIDE_COLOR = Color3.fromRGB(255, 100, 115)
const SIDE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = BLUE_SIDE_COLOR,
	Red = RED_SIDE_COLOR,
}
-- A slate blue-green that lets the bed show through near the banks.
const WATER_COLOR = Color3.fromRGB(44, 84, 98)
const WATER_TRANSPARENCY = 0.45
const WATER_REFLECTANCE = 0.4
const WATER_WAVE_SIZE = 0.1
const WATER_WAVE_SPEED = 10
const FALL_COLOR = Color3.fromRGB(205, 228, 236)
const FALL_STREAK_COLOR = Color3.fromRGB(245, 250, 252)
const RING_FLOOR_COLOR = Color3.fromRGB(96, 98, 86)
const RING_COLOR = Color3.fromRGB(255, 210, 110)
const BASE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = Color3.fromRGB(150, 160, 178),
	Red = Color3.fromRGB(150, 120, 110),
}
const PAD_FLOOR_COLOR = Color3.fromRGB(90, 92, 82)
const CAMP_COLORS: { [MapLayout.CampKind]: Color3 } = {
	Small = Color3.fromRGB(150, 230, 110),
	CrystalGolem = Color3.fromRGB(110, 180, 255),
	EmberBeetle = Color3.fromRGB(255, 130, 60),
	Skyray = Color3.fromRGB(120, 230, 255),
	HiveQueen = Color3.fromRGB(190, 90, 230),
}
const LAUNCH_COLOR = Color3.fromRGB(255, 220, 120)
const CRYSTAL_COLOR = Color3.fromRGB(150, 190, 255)
const CRYSTAL_CORE_COLOR = Color3.fromRGB(210, 230, 255)
const PLANT_COLORS = {
	Color3.fromRGB(60, 140, 60),
	Color3.fromRGB(40, 110, 54),
	Color3.fromRGB(96, 150, 56),
}
const STALK_COLOR = Color3.fromRGB(86, 70, 44)
const BULB_COLOR = Color3.fromRGB(255, 225, 120)
const CAP_COLORS = {
	Color3.fromRGB(220, 60, 50),
	Color3.fromRGB(255, 160, 70),
}
const TRUNK_COLOR = Color3.fromRGB(96, 70, 46)
-- Mostly greens, with a few autumn trees so the forest isn't one flat color.
const LEAF_COLORS = {
	Color3.fromRGB(46, 120, 56),
	Color3.fromRGB(36, 98, 50),
	Color3.fromRGB(70, 140, 52),
	Color3.fromRGB(46, 120, 56),
	Color3.fromRGB(220, 150, 50),
}
const RUIN_COLOR = Color3.fromRGB(150, 146, 132)
const RUNE_COLOR = Color3.fromRGB(120, 200, 255)

-- Every client builds the same scenery from the same seed.
const SCENERY_SEED = 7331

-- Studs of ground drawn past the playable square's edge.
const OUTSIDE_MARGIN = 140
-- Ground at least this far from a lane's edge and the river's bank is
-- jungle, drawn in darker soil.
const JUNGLE_LANE_GAP = 10
const JUNGLE_RIVER_GAP = 6
-- Studs the brush floor reaches past the patch's edge.
const BRUSH_FLOOR_MARGIN = 1
const LANE_EDGE_WIDTH = 0.5
const BASE_EDGE_WIDTH = 0.8
const BASE_INNER_INSET = 8
-- Ground this close above the water's surface is drawn as the muddy bed.
const BED_MARGIN = 0.5
-- Outside the arena the river runs through meadow this many studs past its
-- banks, and scenery keeps this far clear of them.
const OUTSIDE_MEADOW_REACH = 10
const OUTSIDE_RIVER_CLEARANCE = 20
-- Boulders sit about this far from the river's course line, near where its
-- bank meets the water, one per this many studs of the course.
const WATERLINE_REACH = 12
const ROCK_SPACING = 9
const ARENA_ROCK_MIN_RADIUS = 1.2
const ARENA_ROCK_MAX_RADIUS = 2.2
const OUTSIDE_ROCK_MIN_RADIUS = 2
const OUTSIDE_ROCK_MAX_RADIUS = 4.5
-- The big boulder on the grassy point inside the river's last bend.
const BEND_BOULDER = Vector3.new(372, 0, 305)
const BEND_BOULDER_RADIUS = 7
-- Bridges are stone walls along a road's edges wherever the ground beside
-- it drops more than BRIDGE_DEPTH, sampled every BRIDGE_STEP studs.
const BRIDGE_WALL_THICKNESS = 1.6
const BRIDGE_WALL_HEIGHT = 0.9
const BRIDGE_DEPTH = 0.6
const BRIDGE_STEP = 2
-- Platforms sink below the river's bed, and their stone lip shows this many
-- studs past the floor drawn on top.
const PLATFORM_FOOTING = 2
const PLATFORM_LIP = 0.6
-- A platform's top sits this far below zero, under the bottom of the
-- lowest flat shape drawn on it.
const PLATFORM_TOP_GAP = 0.15
-- The cliff the river falls from. The fall stands this far behind its foot,
-- the start of the river's course.
const FALL_SETBACK = 6
const FALL_WIDTH = 14
const FALL_STREAKS = 6
const CLIFF_HEIGHT = 34
const CLIFF_WIDTH = 84
const CLIFF_DEPTH = 34
const CLIFF_BOULDERS = 16
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
const OUTSIDE_CRYSTAL_COUNT = 6
const MUSHROOM_COUNT = 18
const OUTSIDE_TREE_COUNT = 90
const RIDGE_TREE_COUNT = 40
const TREES_PER_WALL = 3
-- Plant blades per stud of a brush patch's length, on top of a base count.
const BLADES_PER_STUD = 1.1
const BASE_BLADES = 14
const BULBS_PER_BRUSH = 3

-- Draw order, bottom to top. Lanes run on into the bases, under the bases'
-- borders.
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
	Returns the function that picks the ground's material and height at each
	spot: meadow along the lanes and the river, mud under the water, dark
	soil and moss in the jungle, grass under brush, and dark rock past the
	arena's edge.
]]
local function createGroundPicker(): (x: number, z: number) -> (Enum.Material, number)
	local laneSegments: { Segment } = {}
	for _, road in MapGround.Roads do
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
	local meadowReach = MapGround.BankReach + OUTSIDE_MEADOW_REACH
	local function pickMaterial(x: number, z: number): Enum.Material
		if math.abs(x) > half or math.abs(z) > half then
			if MapGround.getCourseDistance(x, z) > meadowReach then
				return if math.noise(x / 46, z / 46, 0.37) > 0.12
					then Enum.Material.Slate
					else Enum.Material.Basalt
			end
		else
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
		end
		return if math.noise(x / 50, z / 50, 0.13) > 0.15
			then Enum.Material.Sand
			else Enum.Material.Ground
	end

	return function(x: number, z: number): (Enum.Material, number)
		local height = MapGround.getGroundHeight(x, z)
		if height < MapGround.WaterLevel + BED_MARGIN then
			return Enum.Material.Mud, height
		end
		return pickMaterial(x, z), height
	end
end

local function drawGround()
	local terrain = workspace.Terrain
	for material, color in TERRAIN_COLORS do
		terrain:SetMaterialColor(material, color)
	end
	terrain.WaterColor = WATER_COLOR
	terrain.WaterTransparency = WATER_TRANSPARENCY
	terrain.WaterReflectance = WATER_REFLECTANCE
	terrain.WaterWaveSize = WATER_WAVE_SIZE
	terrain.WaterWaveSpeed = WATER_WAVE_SPEED
	MapClientService:PaintGround(
		MapLayout.HalfSize + OUTSIDE_MARGIN,
		createGroundPicker(),
		MapGround.WaterLevel
	)
end

--[[
	Rounded blue-gray boulders along the river's waterline: small ones inside
	the arena, where units walk past them, and bigger ones outside it.
]]
local function drawRiverRocks()
	local terrain = workspace.Terrain
	local half = MapLayout.HalfSize
	local course = MapGround.Course
	for index = 1, #course - 1 do
		local from = course[index]
		local to = course[index + 1]
		local side = getNormal(from, to)
		local count = math.floor((to - from).Magnitude / ROCK_SPACING + random:NextNumber())
		for _ = 1, count do
			local along = from:Lerp(to, random:NextNumber())
			local isOutside = math.abs(along.X) > half or math.abs(along.Z) > half
			local radius = if isOutside
				then random:NextNumber(OUTSIDE_ROCK_MIN_RADIUS, OUTSIDE_ROCK_MAX_RADIUS)
				else random:NextNumber(ARENA_ROCK_MIN_RADIUS, ARENA_ROCK_MAX_RADIUS)
			local sign = if random:NextNumber() < 0.5 then 1 else -1
			local spot = along + side * sign * (WATERLINE_REACH + random:NextNumber(-3, 2))
			local isClear = MapGround.getRoadDistance(spot.X, spot.Z)
					> MapLayout.LaneWidth / 2 + radius + 1
				and MapGround.getPlatformGap(spot.X, spot.Z) > radius + 1
			if isClear then
				local sink = radius * random:NextNumber(0.2, 0.5)
				terrain:FillBall(
					spot + Vector3.new(0, MapGround.WaterLevel - sink, 0),
					radius,
					Enum.Material.Limestone
				)
			end
		end
	end

	terrain:FillBall(BEND_BOULDER, BEND_BOULDER_RADIUS, Enum.Material.Limestone)
	for _ = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)).Unit
		local radius = BEND_BOULDER_RADIUS * random:NextNumber(0.4, 0.6)
		terrain:FillBall(
			BEND_BOULDER + offset * BEND_BOULDER_RADIUS - Vector3.new(0, radius * 0.4, 0),
			radius,
			Enum.Material.Limestone
		)
	end
end

local function drawBridgeWall(from: Vector3, to: Vector3)
	local direction = (to - from).Unit
	local start = from - direction * BRIDGE_STEP / 2
	local finish = to + direction * BRIDGE_STEP / 2
	local bottom = MapGround.BedHeight - 1
	local height = BRIDGE_WALL_HEIGHT - bottom
	local lift = Vector3.new(0, bottom + height / 2, 0)
	MapClientService:DrawProp(
		CFrame.lookAt((start + finish) / 2 + lift, finish + lift),
		Vector3.new(BRIDGE_WALL_THICKNESS, height, (finish - start).Magnitude),
		RUIN_COLOR,
		{ Material = Enum.Material.Cobblestone, CastsShadow = true }
	)
end

--[[
	Roads cross the river on causeways. Stone walls line each causeway's
	sides, so it reads as a bridge over the water.
]]
local function drawBridges()
	local offset = MapLayout.LaneWidth / 2 + BRIDGE_WALL_THICKNESS / 2
	for _, road in MapGround.Roads do
		for index = 1, #road - 1 do
			local from = road[index]
			local to = road[index + 1]
			local steps = math.ceil((to - from).Magnitude / BRIDGE_STEP)
			for _, sign in { 1, -1 } do
				local shift = getNormal(from, to) * sign * offset
				local runStart: Vector3? = nil
				local last = from + shift
				for step = 0, steps do
					local spot = from:Lerp(to, step / steps) + shift
					-- Where roads meet, a wall would cut across the other road.
					local isWalled = MapGround.getRiverHeight(spot.X, spot.Z) < -BRIDGE_DEPTH
						and MapGround.getPlatformGap(spot.X, spot.Z) > 0
						and MapGround.getRoadDistance(spot.X, spot.Z) >= MapLayout.LaneWidth / 2
					if isWalled and not runStart then
						runStart = spot
					elseif runStart and not isWalled then
						drawBridgeWall(runStart, last)
						runStart = nil
					end
					last = spot
				end
				if runStart then
					drawBridgeWall(runStart, last)
				end
			end
		end
	end
end

--[[
	The crash ring and the river bosses' pits stand on round stone platforms
	rising out of the river.
]]
local function drawPlatforms()
	local depth = -MapGround.BedHeight + PLATFORM_FOOTING
	for _, platform in MapGround.Platforms do
		local diameter = (platform.Radius + PLATFORM_LIP) * 2
		MapClientService:DrawProp(
			CFrame.new(platform.Center - Vector3.new(0, depth / 2 + PLATFORM_TOP_GAP, 0)),
			Vector3.new(diameter, depth, diameter),
			RUIN_COLOR,
			{ Shape = "Cylinder", Material = Enum.Material.Cobblestone, CastsShadow = true }
		)
	end
end

--[[
	The river's source: a waterfall pouring from a notch in a stone cliff,
	with spray where it lands.
]]
local function drawWaterfall()
	local terrain = workspace.Terrain
	local foot = MapGround.Course[1]
	local away = foot - MapGround.Course[2]
	local back = Vector3.new(away.X, 0, away.Z).Unit
	-- Faces into the cliff, so local -Z runs into the rock and +Z out over
	-- the river.
	local face = CFrame.lookAt(foot + back * FALL_SETBACK, foot + back * (FALL_SETBACK + 1))

	terrain:FillBlock(
		face * CFrame.new(0, CLIFF_HEIGHT / 2 - 4, -CLIFF_DEPTH / 2),
		Vector3.new(CLIFF_WIDTH, CLIFF_HEIGHT + 8, CLIFF_DEPTH),
		Enum.Material.Limestone
	)
	for _ = 1, CLIFF_BOULDERS do
		local radius = random:NextNumber(8, 14)
		local lateral = random:NextNumber(-CLIFF_WIDTH / 2, CLIFF_WIDTH / 2)
		-- Boulders bulge out of the face, but never over the fall.
		local depth = if math.abs(lateral) < FALL_WIDTH / 2 + radius
			then -radius - 2
			else -radius * 0.6
		local height = random:NextNumber(0, CLIFF_HEIGHT)
		terrain:FillBall(
			(face * CFrame.new(lateral, height, depth)).Position,
			radius,
			Enum.Material.Limestone
		)
	end
	-- The notch stops short of the cliff's back, so no sky shows through it,
	-- and holds the pool that spills over the edge.
	local notchBack = -CLIFF_DEPTH * 0.7
	terrain:FillBlock(
		face * CFrame.new(0, CLIFF_HEIGHT + 2, (notchBack + 6) / 2),
		Vector3.new(FALL_WIDTH, 8, 6 - notchBack),
		Enum.Material.Air
	)
	terrain:FillBlock(
		face * CFrame.new(0, CLIFF_HEIGHT, (notchBack - 2) / 2),
		Vector3.new(FALL_WIDTH, 4, -2 - notchBack),
		Enum.Material.Water
	)

	local top = CLIFF_HEIGHT + 1
	local bottom = MapGround.WaterLevel
	-- Terrain rounds the face out to its 4-stud cells, so a recess behind
	-- the fall keeps the rock from swallowing it.
	terrain:FillBlock(
		face * CFrame.new(0, (CLIFF_HEIGHT + bottom) / 2, 1.5),
		Vector3.new(FALL_WIDTH, CLIFF_HEIGHT - bottom, 9),
		Enum.Material.Air
	)
	MapClientService:DrawProp(
		face * CFrame.new(0, (top + bottom) / 2, 1),
		Vector3.new(FALL_WIDTH - 2, top - bottom, 1.2),
		FALL_COLOR,
		{ Transparency = 0.2 }
	)
	for _ = 1, FALL_STREAKS do
		local length = random:NextNumber(0.4, 1) * (top - bottom)
		MapClientService:DrawProp(
			face
				* CFrame.new(
					random:NextNumber(-FALL_WIDTH / 2 + 2, FALL_WIDTH / 2 - 2),
					top - length / 2,
					1.8
				),
			Vector3.new(random:NextNumber(0.8, 2), length, 0.3),
			FALL_STREAK_COLOR,
			{ Transparency = 0.45 }
		)
	end
	MapClientService:DrawSpray((face * CFrame.new(0, bottom, 4)).Position, FALL_WIDTH)
	MapClientService:DrawSpray((face * CFrame.new(0, bottom, 9)).Position, FALL_WIDTH * 0.6)
end

local function drawRiver()
	drawRiverRocks()
	drawBridges()
	drawPlatforms()
	drawWaterfall()
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
	for _, road in MapGround.Roads do
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
		local radius = MapLayout.CampRadii[camp.Kind]
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
		-- A landing in the river floats on the water.
		local landingGround = MapGround.getGroundHeight(pad.Landing.X, pad.Landing.Z)
		MapClientService:DrawRing(
			pad.Landing,
			LANDING_RADIUS,
			0.3,
			LAUNCH_COLOR,
			DETAIL_RING_LAYER,
			{
				Material = Enum.Material.Neon,
				Transparency = 0.4,
				Elevation = math.max(landingGround, MapGround.WaterLevel),
			}
		)
		MapClientService:DrawLine(pad.Position, pad.Landing, 0.4, LAUNCH_COLOR, DETAIL_RING_LAYER, {
			Material = Enum.Material.Neon,
			Transparency = 0.75,
		})
	end
end

--[[
	A cluster of magic crystal shards leaning out from a point on the ground,
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
	A round, puffy storybook tree: a trunk under a cluster of leaf balls.
]]
local function drawTree(base: Vector3, scale: number)
	local height = random:NextNumber(4, 6) * scale
	local leaves = LEAF_COLORS[random:NextInteger(1, #LEAF_COLORS)]
	MapClientService:DrawProp(
		CFrame.new(base + Vector3.new(0, height / 2, 0)),
		Vector3.new(0.9 * scale, height, 0.9 * scale),
		TRUNK_COLOR,
		{ Shape = "Cylinder" }
	)
	local crown = base + Vector3.new(0, height, 0)
	for index = 1, random:NextInteger(2, 4) do
		local size = random:NextNumber(3.5, 5) * scale * (if index == 1 then 1.2 else 1)
		local offset = if index == 1
			then Vector3.zero
			else Vector3.new(
				random:NextNumber(-1.6, 1.6),
				random:NextNumber(-0.8, 1),
				random:NextNumber(-1.6, 1.6)
			) * scale
		MapClientService:DrawProp(
			CFrame.new(crown + offset),
			Vector3.one * size,
			leaves,
			{ Shape = "Ball", CastsShadow = true }
		)
	end
end

--[[
	Draws each jungle wall as the server shapes it, a thick line with round
	ends, built as a stone ridge with trees growing on top.
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

		local top = Vector3.new(0, JUNGLE_WALL_HEIGHT - 1.5, 0)
		for index = 1, TREES_PER_WALL do
			local share = (index - 0.5) / TREES_PER_WALL + random:NextNumber(-0.1, 0.1)
			drawTree(wall.From:Lerp(wall.To, share) + top, random:NextNumber(0.8, 1.1))
		end
	end
end

--[[
	A patch of brush: tall fern fronds and a few reeds tipped with glowing
	fireflies, all inside the patch's shape.
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
	A giant toadstool: a pale stalk under a wide cap.
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
		{ Shape = "Ball", CastsShadow = true }
	)
end

local function isNearRiver(spot: Vector3, clearance: number): boolean
	return MapGround.getCourseDistance(spot.X, spot.Z) < MapGround.BankReach + clearance
end

local function pickAnyOutsideSpot(): Vector3
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
	Returns a random spot past the arena's edge, between the ridge and the
	edge of the drawn ground, clear of the river.
]]
local function pickOutsideSpot(): Vector3
	local spot
	repeat
		spot = pickAnyOutsideSpot()
	until not isNearRiver(spot, OUTSIDE_RIVER_CLEARANCE)
	return spot
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
			-- The river leaves the arena through a gap in the ridge.
			if not isNearRiver(center, radius) then
				terrain:FillBall(center - Vector3.new(0, sink, 0), radius, Enum.Material.Rock)
			end
		end
	end
	for _ = 1, RIDGE_TREE_COUNT do
		local along = random:NextNumber(-half, half)
		local spot = if random:NextNumber() < 0.5
			then Vector3.new(along, 4, reach * (if random:NextNumber() < 0.5 then 1 else -1))
			else Vector3.new(reach * (if random:NextNumber() < 0.5 then 1 else -1), 4, along)
		if not isNearRiver(spot, RIDGE_MAX_RADIUS) then
			drawTree(spot, random:NextNumber(1.3, 1.9))
		end
	end
end

--[[
	The forest beyond the rim: rolling hills, stone circles, dense trees, a
	few magic crystals, and giant toadstools.
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
	for _ = 1, OUTSIDE_TREE_COUNT do
		drawTree(pickOutsideSpot(), random:NextNumber(1.6, 2.8))
	end
	for _ = 1, OUTSIDE_CRYSTAL_COUNT do
		drawCrystals(pickOutsideSpot(), random:NextNumber(1.5, 2.8))
	end
	for _ = 1, MUSHROOM_COUNT do
		drawMushroom(pickOutsideSpot(), random:NextNumber(1, 2))
	end
end

--[[
	An old shrine ruin: a ring of stone pillars, some broken short and one
	fallen, around a glowing rune circle. Origin sits on the ground.
]]
local function drawRuin(origin: CFrame, scale: number)
	local stone = { Material = Enum.Material.Cobblestone, CastsShadow = true }
	local function place(offset: CFrame, size: Vector3, color: Color3, options: PropOptions)
		MapClientService:DrawProp(origin * offset, size * scale, color, options)
	end

	place(CFrame.new(0, 0.5 * scale, 0), Vector3.new(34, 1, 34), RUIN_COLOR, stone)
	place(
		CFrame.new(0, 1.05 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.1, 18, 18),
		RUNE_COLOR,
		{ Shape = "Cylinder", Material = Enum.Material.Neon, Transparency = 0.3 }
	)
	const pillarCount = 6
	for index = 1, pillarCount do
		local angle = index / pillarCount * math.pi * 2
		local height = if index % 3 == 0 then random:NextNumber(4, 7) else random:NextNumber(14, 20)
		local spot = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 14
		place(
			CFrame.new((spot + Vector3.new(0, 1 + height / 2, 0)) * scale),
			Vector3.new(3, height, 3),
			RUIN_COLOR,
			{ Shape = "Cylinder", Material = Enum.Material.Cobblestone, CastsShadow = true }
		)
	end
	place(
		CFrame.new(6 * scale, 2.5 * scale, 20 * scale) * CFrame.Angles(math.rad(90), 0.4, 0),
		Vector3.new(3, 16, 3),
		RUIN_COLOR,
		{ Shape = "Cylinder", Material = Enum.Material.Cobblestone, CastsShadow = true }
	)
end

local function drawRuins()
	local half = MapLayout.HalfSize
	-- The two corners away from the bases hold the biggest ruins; smaller
	-- ones stand along the outer edges.
	drawRuin(CFrame.new(-half - 70, 0, -half - 55) * CFrame.Angles(0, math.rad(40), 0), 1.2)
	drawRuin(CFrame.new(half + 60, 0, half + 75) * CFrame.Angles(0, math.rad(-140), 0), 1.1)
	drawRuin(CFrame.new(-half - 60, 0, 40) * CFrame.Angles(0, math.rad(100), 0), 0.55)
	drawRuin(CFrame.new(40, 0, -half - 60) * CFrame.Angles(0, math.rad(190), 0), 0.55)
	drawRuin(CFrame.new(half + 55, 0, -80) * CFrame.Angles(0, math.rad(-70), 0), 0.5)
	drawRuin(CFrame.new(-80, 0, half + 55) * CFrame.Angles(0, math.rad(20), 0), 0.5)
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
	drawRuins()
end

return Module
