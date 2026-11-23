--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const Navigation = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/Navigation"
)

-- Studs a wall's face keeps from each kind of map feature's edge or center.
const LANE_GAP = 4
const RIVER_GAP = 3
const STRUCTURE_GAP = 10
const PAD_GAP = 10
const BASE_GAP = 4
-- Room to fight a camp, in studs from its center, by camp kind.
const CAMP_ROOM: { [MapLayout.CampKind]: number } = {
	Small = 12,
	CrystalGolem = 15,
	EmberBeetle = 15,
	Skyray = 26,
	HiveQueen = 34,
}
-- The widest hero's radius, plus a little room.
const HERO_CLEARANCE = 2.5
-- Studs a brush patch's edge keeps from lanes, the river, and walls, and
-- from towers, whose shots can't reach into it.
const BRUSH_EDGE_GAP = 2
const BRUSH_STRUCTURE_GAP = 30

-- Walls and brush patches share one shape: a thick line with round ends.
type WallSpot = MapLayout.WallSpot

local function closestOnSegment(point: Vector3, from: Vector3, to: Vector3): Vector3
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0 then
		return from
	end
	local share = math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1)
	return from + segment * share
end

local function getPointGap(wall: WallSpot, point: Vector3): number
	return (point - closestOnSegment(point, wall.From, wall.To)).Magnitude - wall.Radius
end

--[[
	Returns the gap between a wall's face and a path's center line, sampled
	along the wall every stud. Walls are short, so sampling is exact enough.
]]
local function getPathGap(wall: WallSpot, path: { Vector3 }): number
	local gap = math.huge
	local length = (wall.To - wall.From).Magnitude
	local steps = math.max(math.ceil(length), 1)
	for step = 0, steps do
		local point = wall.From:Lerp(wall.To, step / steps)
		for index = 1, #path - 1 do
			local closest = closestOnSegment(point, path[index], path[index + 1])
			gap = math.min(gap, (point - closest).Magnitude - wall.Radius)
		end
	end
	return gap
end

local function isInsideBase(point: Vector3, base: MapLayout.Base, margin: number): boolean
	local half = base.Size / 2 + margin
	return math.abs(point.X - base.Center.X) <= half and math.abs(point.Z - base.Center.Z) <= half
end

describe("MapLayout", function()
	it("keeps every jungle wall clear of lanes, the river, camps, and buildings", function()
		local offenders = {}
		local function check(index: number, feature: string, gap: number, required: number)
			if gap < required then
				table.insert(offenders, `wall {index} is {gap} studs from {feature}`)
			end
		end

		for index, wall in MapLayout.Walls do
			for team, routes in MapLayout.Routes do
				for laneName, route in routes do
					local gap = getPathGap(wall, route) - MapLayout.LaneWidth / 2
					check(index, `{team} {laneName} lane`, gap, LANE_GAP)
				end
			end
			local riverGap = getPathGap(wall, MapLayout.River) - MapLayout.RiverWidth / 2
			check(index, "the river", riverGap, RIVER_GAP)
			for _, camp in MapLayout.Camps do
				local gap = getPointGap(wall, camp.Position)
				check(index, `camp {camp.Key}`, gap, CAMP_ROOM[camp.Kind])
			end
			for _, spot in MapLayout.Structures do
				local name = `{spot.Team} {spot.Id}`
				check(index, name, getPointGap(wall, spot.Position), STRUCTURE_GAP)
			end
			for _, pad in MapLayout.LaunchPads do
				check(index, `{pad.Team} launch pad`, getPointGap(wall, pad.Position), PAD_GAP)
				check(index, `{pad.Team} landing`, getPointGap(wall, pad.Landing), PAD_GAP)
			end
			for team, base in MapLayout.Bases do
				local middle = wall.From:Lerp(wall.To, 0.5)
				for _, point in { wall.From, middle, wall.To } do
					if isInsideBase(point, base, wall.Radius + BASE_GAP) then
						table.insert(offenders, `wall {index} reaches into the {team} base`)
						break
					end
				end
			end
		end

		expect(offenders).toEqual({})
	end)

	it("keeps every brush patch beside the lanes and clear of camps and towers", function()
		local offenders = {}
		local function check(index: number, feature: string, gap: number, required: number)
			if gap < required then
				table.insert(offenders, `brush {index} is {gap} studs from {feature}`)
			end
		end

		for index, brush in MapLayout.Brushes do
			for team, routes in MapLayout.Routes do
				for laneName, route in routes do
					local gap = getPathGap(brush, route) - MapLayout.LaneWidth / 2
					check(index, `{team} {laneName} lane`, gap, BRUSH_EDGE_GAP)
				end
			end
			local riverGap = getPathGap(brush, MapLayout.River) - MapLayout.RiverWidth / 2
			check(index, "the river", riverGap, BRUSH_EDGE_GAP)
			for wallIndex, wall in MapLayout.Walls do
				local gap = getPathGap(brush, { wall.From, wall.To }) - wall.Radius
				check(index, `wall {wallIndex}`, gap, BRUSH_EDGE_GAP)
			end
			for _, camp in MapLayout.Camps do
				local gap = getPointGap(brush, camp.Position)
				check(index, `camp {camp.Key}`, gap, CAMP_ROOM[camp.Kind])
			end
			for _, spot in MapLayout.Structures do
				local name = `{spot.Team} {spot.Id}`
				check(index, name, getPointGap(brush, spot.Position), BRUSH_STRUCTURE_GAP)
			end
			for _, pad in MapLayout.LaunchPads do
				check(index, `{pad.Team} launch pad`, getPointGap(brush, pad.Position), PAD_GAP)
				check(index, `{pad.Team} landing`, getPointGap(brush, pad.Landing), PAD_GAP)
			end
		end

		expect(offenders).toEqual({})
	end)

	it("lets every camp be reached from both fountains", function()
		local navigation = Navigation.new(MapLayout.Walls, HERO_CLEARANCE)
		local unreachable = {}

		for team, base in MapLayout.Bases do
			for _, camp in MapLayout.Camps do
				local path = Navigation.findPath(navigation, base.Fountain, camp.Position)
				local from = Navigation.pushOut(navigation, base.Fountain, HERO_CLEARANCE)
				for _, to in path do
					if not Navigation.isClear(navigation, from, to) then
						table.insert(unreachable, `{camp.Key} from the {team} fountain`)
						break
					end
					from = to
				end
			end
		end

		expect(unreachable).toEqual({})
	end)
end)
