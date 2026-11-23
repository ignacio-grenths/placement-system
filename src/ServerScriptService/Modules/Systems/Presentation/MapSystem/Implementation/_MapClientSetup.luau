--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const MapClientService = require("../SystemPackage/MapClientService")

-- Crashpoint Valley: a dark metal floor where an alien mothership came down,
-- lit by neon. Units carry the bright colors, so the floor stays dark and
-- calm for them to read against.
const OUTSIDE_COLOR = Color3.fromRGB(24, 25, 32)
const FLOOR_COLOR = Color3.fromRGB(30, 35, 46)
const GRID_COLOR = Color3.fromRGB(70, 130, 200)
const LANE_COLOR = Color3.fromRGB(52, 60, 80)
const BLUE_SIDE_COLOR = Color3.fromRGB(90, 160, 255)
const RED_SIDE_COLOR = Color3.fromRGB(255, 100, 115)
const SIDE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = BLUE_SIDE_COLOR,
	Red = RED_SIDE_COLOR,
}
const RIVER_BED_COLOR = Color3.fromRGB(12, 38, 56)
const RIVER_ENERGY_COLOR = Color3.fromRGB(20, 120, 190)
const RIVER_BANK_COLOR = Color3.fromRGB(60, 210, 255)
-- The energy surface shimmers over a dark bed; opaque, it glares.
const RIVER_ENERGY_TRANSPARENCY = 0.35
const RING_FLOOR_COLOR = Color3.fromRGB(26, 22, 42)
const RING_COLOR = Color3.fromRGB(180, 120, 255)
const BASE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = Color3.fromRGB(22, 32, 58),
	Red = Color3.fromRGB(58, 22, 32),
}
const PAD_FLOOR_COLOR = Color3.fromRGB(18, 22, 30)
const CAMP_COLORS: { [MapLayout.CampKind]: Color3 } = {
	Small = Color3.fromRGB(90, 220, 160),
	CrystalGolem = Color3.fromRGB(110, 180, 255),
	EmberBeetle = Color3.fromRGB(255, 130, 60),
	Skyray = Color3.fromRGB(120, 230, 255),
	HiveQueen = Color3.fromRGB(190, 90, 230),
}
const LAUNCH_COLOR = Color3.fromRGB(120, 255, 180)
const WALL_COLOR = Color3.fromRGB(34, 38, 50)
const WALL_LIGHT_COLOR = Color3.fromRGB(90, 200, 255)
const HULL_COLOR = Color3.fromRGB(86, 92, 110)
-- Bloom pushes orange toward yellow, so the glow starts deep.
const HULL_GLOW_COLOR = Color3.fromRGB(255, 110, 50)

-- Red's routes are Blue's run backward, so drawing Blue's covers every lane.
const DRAWN_ROUTES_TEAM: MapLayout.MapTeam = "Blue"

-- Studs of dark ground drawn past the playable square's edge.
const OUTSIDE_MARGIN = 140
const GRID_SPACING = 25
const GRID_WIDTH = 0.25
const GRID_TRANSPARENCY = 0.8
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
const WALL_HEIGHT = 5
const WALL_THICKNESS = 4
const WALL_STRIP_HEIGHT = 0.3
const WALL_STRIP_WIDTH = 0.6
const WALL_POST_HEIGHT = 7
const WALL_POST_WIDTH = 5
const WALL_POST_SPACING = 60
-- Jungle walls stay low, so the overhead camera still sees units behind them.
const JUNGLE_WALL_HEIGHT = 4
const JUNGLE_WALL_COLOR = Color3.fromRGB(54, 60, 78)
const JUNGLE_WALL_STRIP_WIDTH = 0.4

-- Draw order, bottom to top. Lanes bridge the river and run on into the
-- bases, under the bases' borders.
const FLOOR_LAYER = 0.3
const GRID_LAYER = 0.6
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

type PropOptions = MapClientService.PropOptions

local Module = {}

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

local function drawFloor()
	-- Rough rock outside the arena, against its smooth metal floor.
	MapClientService:DrawGround(MapLayout.HalfSize + OUTSIDE_MARGIN, OUTSIDE_COLOR, {
		Material = Enum.Material.Slate,
	})
	MapClientService:DrawSquare(Vector3.zero, MapLayout.HalfSize * 2, FLOOR_COLOR, FLOOR_LAYER)

	local half = MapLayout.HalfSize
	local gridOptions = { Material = Enum.Material.Neon, Transparency = GRID_TRANSPARENCY }
	for offset = -half + GRID_SPACING, half - GRID_SPACING, GRID_SPACING do
		MapClientService:DrawLine(
			Vector3.new(offset, 0, -half),
			Vector3.new(offset, 0, half),
			GRID_WIDTH,
			GRID_COLOR,
			GRID_LAYER,
			gridOptions
		)
		MapClientService:DrawLine(
			Vector3.new(-half, 0, offset),
			Vector3.new(half, 0, offset),
			GRID_WIDTH,
			GRID_COLOR,
			GRID_LAYER,
			gridOptions
		)
	end
end

local function drawRiver()
	local width = MapLayout.RiverWidth
	MapClientService:DrawPath(MapLayout.River, width, RIVER_BED_COLOR, RIVER_LAYER)
	MapClientService:DrawPath(MapLayout.River, width - 4, RIVER_ENERGY_COLOR, RIVER_ENERGY_LAYER, {
		Material = Enum.Material.ForceField,
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

local function findCore(team: MapLayout.MapTeam): Vector3?
	for _, spot in MapLayout.Structures do
		if spot.Team == team and spot.Tier == "Core" then
			return spot.Position
		end
	end
	return nil
end

local function drawLanes()
	-- Routes start beside their core, so each road is drawn on into it.
	local core = findCore(DRAWN_ROUTES_TEAM)
	for _, route in MapLayout.Routes[DRAWN_ROUTES_TEAM] do
		local road = table.clone(route)
		if core then
			table.insert(road, 1, core)
		end
		MapClientService:DrawPath(road, MapLayout.LaneWidth, LANE_COLOR, LANE_LAYER)

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
		MapClientService:DrawDisc(fountain, base.FountainRadius - 2, sideColor, DETAIL_GLOW_LAYER, {
			Material = Enum.Material.ForceField,
		})
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
		MapClientService:DrawDisc(pad.Position, PAD_RADIUS, LAUNCH_COLOR, DETAIL_GLOW_LAYER, {
			Material = Enum.Material.ForceField,
		})
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
	Draws each jungle wall as the server shapes it: a block between its two
	points with round ends, topped by a light strip.
]]
local function drawJungleWalls()
	local metal = { Material = Enum.Material.Metal, CastsShadow = true }
	local lift = Vector3.new(0, JUNGLE_WALL_HEIGHT / 2, 0)
	for _, wall in MapLayout.Walls do
		local length = (wall.To - wall.From).Magnitude
		local thickness = wall.Radius * 2
		MapClientService:DrawProp(
			CFrame.lookAt(wall.From:Lerp(wall.To, 0.5) + lift, wall.To + lift),
			Vector3.new(thickness, JUNGLE_WALL_HEIGHT, length),
			JUNGLE_WALL_COLOR,
			metal
		)
		for _, point in { wall.From, wall.To } do
			MapClientService:DrawProp(
				CFrame.new(point + lift),
				Vector3.new(thickness, JUNGLE_WALL_HEIGHT, thickness),
				JUNGLE_WALL_COLOR,
				{ Shape = "Cylinder", Material = Enum.Material.Metal, CastsShadow = true }
			)
		end

		local stripLift = Vector3.new(0, JUNGLE_WALL_HEIGHT + WALL_STRIP_HEIGHT / 2, 0)
		MapClientService:DrawProp(
			CFrame.lookAt(wall.From:Lerp(wall.To, 0.5) + stripLift, wall.To + stripLift),
			Vector3.new(JUNGLE_WALL_STRIP_WIDTH, WALL_STRIP_HEIGHT, length),
			WALL_LIGHT_COLOR,
			NEON
		)
	end
end

local function drawWalls()
	local half = MapLayout.HalfSize
	local center = half + WALL_THICKNESS / 2
	local length = (half + WALL_THICKNESS) * 2
	local metal = { Material = Enum.Material.Metal }
	-- Each wall runs along X or Z, through the point given.
	local walls = {
		{ Position = Vector3.new(0, 0, -center), IsAlongX = true },
		{ Position = Vector3.new(0, 0, center), IsAlongX = true },
		{ Position = Vector3.new(-center, 0, 0), IsAlongX = false },
		{ Position = Vector3.new(center, 0, 0), IsAlongX = false },
	}
	for _, wall in walls do
		local body = if wall.IsAlongX
			then Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS)
			else Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length)
		local strip = if wall.IsAlongX
			then Vector3.new(length, WALL_STRIP_HEIGHT, WALL_STRIP_WIDTH)
			else Vector3.new(WALL_STRIP_WIDTH, WALL_STRIP_HEIGHT, length)
		MapClientService:DrawProp(
			CFrame.new(wall.Position + Vector3.new(0, WALL_HEIGHT / 2, 0)),
			body,
			WALL_COLOR,
			metal
		)
		MapClientService:DrawProp(
			CFrame.new(wall.Position + Vector3.new(0, WALL_HEIGHT + WALL_STRIP_HEIGHT / 2, 0)),
			strip,
			WALL_LIGHT_COLOR,
			NEON
		)

		-- Posts a step taller than the wall, each with a glowing cap.
		for offset = -half, half, WALL_POST_SPACING do
			local base = if wall.IsAlongX
				then Vector3.new(offset, 0, wall.Position.Z)
				else Vector3.new(wall.Position.X, 0, offset)
			MapClientService:DrawProp(
				CFrame.new(base + Vector3.new(0, WALL_POST_HEIGHT / 2, 0)),
				Vector3.new(WALL_POST_WIDTH, WALL_POST_HEIGHT, WALL_POST_WIDTH),
				WALL_COLOR,
				metal
			)
			MapClientService:DrawProp(
				CFrame.new(base + Vector3.new(0, WALL_POST_HEIGHT + WALL_STRIP_HEIGHT / 2, 0)),
				Vector3.new(WALL_POST_WIDTH, WALL_STRIP_HEIGHT, WALL_POST_WIDTH),
				WALL_LIGHT_COLOR,
				NEON
			)
		end
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
	drawFloor()
	drawRiver()
	drawCrashRing()
	drawLanes()
	drawBases()
	drawCamps()
	drawLaunchPads()
	drawJungleWalls()
	drawWalls()
	drawWreckage()
end

return Module
