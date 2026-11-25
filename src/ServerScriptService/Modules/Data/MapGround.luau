--!strict

const MapLayout = require("./MapLayout")

-- The ground is flat at height zero except where the river cuts its channel.
-- Heights are in studs.
const WATER_LEVEL = -3
const BED_HEIGHT = -7
-- Studs from the river's course line: the bed is flat out to BED_REACH,
-- and the bank rises from there to meet the ground at BANK_REACH.
const BED_REACH = 3
const BANK_REACH = 22
-- The banks wander in and out by up to BANK_WOBBLE studs, so they never run
-- ruler-straight.
const BANK_WOBBLE = 3
const WOBBLE_SCALE = 28
const WOBBLE_SEED = 0.53
-- Inside the arena the course swings to each side of the gameplay river's
-- line. A whole number of half waves keeps both ends on the line, where the
-- course carries on past the corners.
const MEANDER = 3
const MEANDER_WAVES = 2.5
const MEANDER_STEP = 24
const SMOOTHING_STEPS = 3
-- Past the arena's corners the river bends around the corner ruins. It
-- falls from a cliff past the top lane's corner and runs off the edge of the
-- world past the bot lane's corner. World positions, in the order it flows.
const SOURCE_COURSE = {
	Vector3.new(-334, 0, -412),
	Vector3.new(-326, 0, -378),
	Vector3.new(-318, 0, -338),
	Vector3.new(-300, 0, -300),
}
const MOUTH_COURSE = {
	Vector3.new(300, 0, 300),
	Vector3.new(340, 0, 330),
	Vector3.new(385, 0, 335),
	Vector3.new(420, 0, 315),
	Vector3.new(470, 0, 322),
}
-- Units wade this deep and no deeper, wherever the bed drops away.
const WADE_DEPTH = 1
-- Roads cross the river as causeways this many studs wider than the lane on
-- each side.
const ROAD_SHOULDER = 1
-- Studs from the course past which getCourseDistance stops measuring.
const SEARCH_REACH = 60
-- Red's routes are Blue's run backward, so Blue's cover every lane.
const ROADS_TEAM: MapLayout.MapTeam = "Blue"

-- A straight piece of a path with the box it reaches, so a spot far away is
-- skipped with four comparisons.
type Segment = {
	AX: number,
	AZ: number,
	BX: number,
	BZ: number,
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

-- A round stone platform the river runs under, level with the ground.
export type Platform = {
	Center: Vector3,
	Radius: number,
}

local Module = {}

--[[
	Rounds the corners of a path into a Catmull-Rom curve through its points.
]]
local function smoothPath(points: { Vector3 }): { Vector3 }
	local smoothed = { points[1] }
	for index = 1, #points - 1 do
		local before = points[math.max(index - 1, 1)]
		local from = points[index]
		local to = points[index + 1]
		local after = points[math.min(index + 2, #points)]
		for step = 1, SMOOTHING_STEPS do
			local t = step / SMOOTHING_STEPS
			local point = 2 * from
				+ (to - before) * t
				+ (2 * before - 5 * from + 4 * to - after) * t ^ 2
				+ (3 * from - before - 3 * to + after) * t ^ 3
			table.insert(smoothed, point * 0.5)
		end
	end
	return smoothed
end

local function buildCourse(): { Vector3 }
	local course = table.clone(SOURCE_COURSE)
	local from = MapLayout.River[1]
	local to = MapLayout.River[#MapLayout.River]
	local side = Vector3.new(-(to - from).Z, 0, (to - from).X).Unit
	local steps = math.ceil((to - from).Magnitude / MEANDER_STEP)
	for step = 0, steps do
		local share = step / steps
		local swing = math.sin(share * MEANDER_WAVES * 2 * math.pi) * MEANDER
		table.insert(course, from:Lerp(to, share) + side * swing)
	end
	table.move(MOUTH_COURSE, 1, #MOUTH_COURSE, #course + 1, course)
	return smoothPath(course)
end

-- Routes start beside their core, so each road runs on into it.
local function buildRoads(): { { Vector3 } }
	local core: Vector3? = nil
	for _, spot in MapLayout.Structures do
		if spot.Team == ROADS_TEAM and spot.Tier == "Core" then
			core = spot.Position
		end
	end
	local roads = {}
	for _, route in MapLayout.Routes[ROADS_TEAM] do
		local road = table.clone(route)
		if core then
			table.insert(road, 1, core)
		end
		table.insert(roads, road)
	end
	return roads
end

local function buildPlatforms(): { Platform }
	local ring = MapLayout.CrashRing
	local platforms = { { Center = ring.Position, Radius = ring.Radius } }
	for _, camp in MapLayout.Camps do
		if not camp.Team then
			table.insert(platforms, {
				Center = camp.Position,
				Radius = MapLayout.CampRadii[camp.Kind],
			})
		end
	end
	return platforms
end

local function toSegments(points: { Vector3 }, reach: number): { Segment }
	local segments = {}
	for index = 1, #points - 1 do
		local from = points[index]
		local to = points[index + 1]
		table.insert(segments, {
			AX = from.X,
			AZ = from.Z,
			BX = to.X,
			BZ = to.Z,
			MinX = math.min(from.X, to.X) - reach,
			MaxX = math.max(from.X, to.X) + reach,
			MinZ = math.min(from.Z, to.Z) - reach,
			MaxZ = math.max(from.Z, to.Z) + reach,
		})
	end
	return segments
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
		if x >= segment.MinX and x <= segment.MaxX and z >= segment.MinZ and z <= segment.MaxZ then
			nearest = math.min(nearest, getSegmentDistance(x, z, segment))
		end
	end
	return nearest
end

Module.WaterLevel = WATER_LEVEL
Module.BedHeight = BED_HEIGHT
Module.BankReach = BANK_REACH
-- The river's center line from the waterfall's foot to past the world's
-- edge. Drawn only: gameplay uses MapLayout.River, which stays on the line
-- the map mirrors across.
Module.Course = buildCourse()
Module.Roads = buildRoads()
Module.Platforms = buildPlatforms()

const courseSegments = toSegments(Module.Course, SEARCH_REACH)
const roadSegments: { Segment } = {}
for _, road in Module.Roads do
	table.move(toSegments(road, math.huge), 1, #road - 1, #roadSegments + 1, roadSegments)
end

--[[
	Returns the distance from a spot to the river's course line, or math.huge
	for a spot more than 60 studs from it.
]]
function Module.getCourseDistance(x: number, z: number): number
	return getNearestDistance(x, z, courseSegments)
end

function Module.getRoadDistance(x: number, z: number): number
	return getNearestDistance(x, z, roadSegments)
end

--[[
	Returns how far a spot is outside the nearest platform's edge, negative
	inside one.
]]
function Module.getPlatformGap(x: number, z: number): number
	local gap = math.huge
	for _, platform in Module.Platforms do
		local offset = Vector3.new(x - platform.Center.X, 0, z - platform.Center.Z)
		gap = math.min(gap, offset.Magnitude - platform.Radius)
	end
	return gap
end

--[[
	Returns the height of the river's channel at a spot, ignoring the
	bridges and platforms over it: zero on dry ground.
]]
function Module.getRiverHeight(x: number, z: number): number
	local wobble = math.noise(x / WOBBLE_SCALE, z / WOBBLE_SCALE, WOBBLE_SEED) * BANK_WOBBLE
	local distance = Module.getCourseDistance(x, z) + wobble
	if distance >= BANK_REACH then
		return 0
	end
	local share = math.clamp((distance - BED_REACH) / (BANK_REACH - BED_REACH), 0, 1)
	return BED_HEIGHT * (1 - share * share * (3 - 2 * share))
end

--[[
	Returns the height of the ground's surface at a spot. Roads and platforms
	stay at ground height where they cross the river.
]]
function Module.getGroundHeight(x: number, z: number): number
	local height = Module.getRiverHeight(x, z)
	if height >= 0 then
		return 0
	end
	local isCrossing = Module.getPlatformGap(x, z) <= 0
		or Module.getRoadDistance(x, z) <= MapLayout.LaneWidth / 2 + ROAD_SHOULDER
	return if isCrossing then 0 else height
end

--[[
	Returns the height a unit's feet rest at: the ground, or wading depth in
	the river.
]]
function Module.getStandingHeight(x: number, z: number): number
	return math.max(Module.getGroundHeight(x, z), WATER_LEVEL - WADE_DEPTH)
end

return Module
