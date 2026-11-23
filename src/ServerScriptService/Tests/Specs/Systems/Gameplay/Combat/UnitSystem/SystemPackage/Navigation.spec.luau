--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const Navigation = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/Navigation"
)

-- One wall along the X axis, from X = -10 to X = 10, so distances to it
-- are easy to work out by hand.
const WALL_HALF_LENGTH = 10
const WALL_RADIUS = 1
const CLEARANCE = 1
const SAMPLE_STEP = 0.25

const NAVIGATION = Navigation.new({
	{
		From = Vector3.new(-WALL_HALF_LENGTH, 0, 0),
		To = Vector3.new(WALL_HALF_LENGTH, 0, 0),
		Radius = WALL_RADIUS,
	},
}, CLEARANCE)

local function getDistanceToWall(point: Vector3): number
	if math.abs(point.X) <= WALL_HALF_LENGTH then
		return math.abs(point.Z)
	end
	local endX = if point.X > 0 then WALL_HALF_LENGTH else -WALL_HALF_LENGTH
	return (point - Vector3.new(endX, 0, 0)).Magnitude
end

--[[
	Returns the smallest distance to the wall's center line along the path,
	sampled every SAMPLE_STEP studs.
]]
local function getClosestApproach(start: Vector3, path: { Vector3 }): number
	local closest = math.huge
	local from = start
	for _, to in path do
		local length = (to - from).Magnitude
		local steps = math.max(math.ceil(length / SAMPLE_STEP), 1)
		for step = 0, steps do
			local point = from:Lerp(to, step / steps)
			closest = math.min(closest, getDistanceToWall(point))
		end
		from = to
	end
	return closest
end

describe("Navigation", function()
	it("walks straight to a goal nothing stands in front of", function()
		local goal = Vector3.new(30, 0, -20)

		local path = Navigation.findPath(NAVIGATION, Vector3.new(0, 0, -20), goal)

		expect(#path).toBe(1)
		expect((path[1] - goal).Magnitude).toBeLessThan(0.01)
	end)

	it("goes around a wall instead of through it", function()
		local start = Vector3.new(0, 0, -10)
		local goal = Vector3.new(0, 0, 10)

		local path = Navigation.findPath(NAVIGATION, start, goal)

		-- The path's corners are sampled, so a hair under the clearance passes.
		local required = WALL_RADIUS + CLEARANCE - 0.05
		expect((path[#path] - goal).Magnitude).toBeLessThan(0.01)
		expect(getClosestApproach(start, path)).toBeGreaterThanOrEqual(required)
	end)

	it("moves a goal inside a wall out to the wall's side", function()
		local path = Navigation.findPath(NAVIGATION, Vector3.new(0, 0, 10), Vector3.new(0, 0, 0.5))

		expect(getDistanceToWall(path[#path])).toBeGreaterThanOrEqual(WALL_RADIUS + CLEARANCE)
	end)

	it.each({
		{
			Case = "a unit overlapping the wall is pushed to touch its face",
			Point = Vector3.new(0, 0, 0.5),
			Expected = Vector3.new(0, 0, 2.5),
		},
		{
			Case = "a unit clear of the wall stays where it is",
			Point = Vector3.new(0, 0, 5),
			Expected = Vector3.new(0, 0, 5),
		},
	})("pushes units out of walls: $Case", function(row)
		local pushed = Navigation.pushOut(NAVIGATION, row.Point, 1.5)

		expect((pushed - row.Expected).Magnitude).toBeLessThan(0.01)
	end)
end)
