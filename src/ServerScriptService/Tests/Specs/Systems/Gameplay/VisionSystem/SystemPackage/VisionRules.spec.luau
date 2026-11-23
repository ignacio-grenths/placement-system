--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const VisionRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/VisionSystem/SystemPackage/VisionRules"
)

-- Two patches of brush, side by side along X with open ground between.
const BRUSHES: { VisionRules.Brush } = {
	{ From = Vector3.new(0, 0, 0), To = Vector3.new(10, 0, 0), Radius = 3 },
	{ From = Vector3.new(30, 0, 0), To = Vector3.new(40, 0, 0), Radius = 3 },
}

type SightRow = {
	Case: string,
	ViewerPosition: Vector3,
	Spot: Vector3,
	Expected: boolean,
}

describe("VisionRules", function()
	it("finds the brush a spot stands in, round ends included", function()
		local inFirst = VisionRules.findBrush(BRUSHES, Vector3.new(5, 0, 2))
		local pastSecondEnd = VisionRules.findBrush(BRUSHES, Vector3.new(42, 0, 0))
		local between = VisionRules.findBrush(BRUSHES, Vector3.new(20, 0, 0))

		expect(inFirst).toBe(1)
		expect(pastSecondEnd).toBe(2)
		expect(between).toBeNil()
	end)

	local rows: { SightRow } = {
		{
			Case = "an open spot in range is seen",
			ViewerPosition = Vector3.new(20, 0, 10),
			Spot = Vector3.new(20, 0, 0),
			Expected = true,
		},
		{
			Case = "an open spot out of range is not",
			ViewerPosition = Vector3.new(20, 0, 30),
			Spot = Vector3.new(20, 0, 0),
			Expected = false,
		},
		{
			Case = "brush hides a spot from a viewer outside it",
			ViewerPosition = Vector3.new(5, 0, 8),
			Spot = Vector3.new(5, 0, 0),
			Expected = false,
		},
		{
			Case = "a viewer in the same brush sees into it",
			ViewerPosition = Vector3.new(9, 0, 0),
			Spot = Vector3.new(1, 0, 0),
			Expected = true,
		},
		{
			Case = "a viewer in other brush does not",
			ViewerPosition = Vector3.new(30, 0, 0),
			Spot = Vector3.new(10, 0, 0),
			Expected = false,
		},
		{
			Case = "a viewer in brush still sees out of it",
			ViewerPosition = Vector3.new(10, 0, 0),
			Spot = Vector3.new(20, 0, 0),
			Expected = true,
		},
	}

	-- A wall across the open ground between the two brush patches.
	local walls: { VisionRules.Wall } = {
		{ From = Vector3.new(20, 0, -10), To = Vector3.new(20, 0, 10), Radius = 1 },
	}
	local wallRows: { SightRow } = {
		{
			Case = "a wall between viewer and spot hides it",
			ViewerPosition = Vector3.new(14, 0, 0),
			Spot = Vector3.new(26, 0, 0),
			Expected = false,
		},
		{
			Case = "a line past the wall's round end is clear",
			ViewerPosition = Vector3.new(14, 0, 13),
			Spot = Vector3.new(26, 0, 13),
			Expected = true,
		},
		{
			Case = "a line grazing the wall's round end is blocked",
			ViewerPosition = Vector3.new(14, 0, 10.5),
			Spot = Vector3.new(26, 0, 10.5),
			Expected = false,
		},
	}

	it.each(wallRows)("lets walls block sight: $Case", function(row: SightRow)
		local viewers: { VisionRules.Viewer } = {
			{ Position = row.ViewerPosition, Sight = 25, Brush = nil },
		}

		local isSeen = VisionRules.canSee(viewers, row.Spot, nil, walls)

		expect(isSeen).toBe(row.Expected)
	end)

	it.each(rows)("decides what a viewer sees: $Case", function(row: SightRow)
		local viewers: { VisionRules.Viewer } = {
			{
				Position = row.ViewerPosition,
				Sight = 25,
				Brush = VisionRules.findBrush(BRUSHES, row.ViewerPosition),
			},
		}
		local spotBrush = VisionRules.findBrush(BRUSHES, row.Spot)

		local isSeen = VisionRules.canSee(viewers, row.Spot, spotBrush)

		expect(isSeen).toBe(row.Expected)
	end)
end)
