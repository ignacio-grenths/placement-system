--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const BotRoute =
	require("@game/ServerScriptService/Modules/Systems/Gameplay/BotSystem/SystemPackage/BotRoute")

-- An L-shaped fixture lane 20 studs long: 10 studs along X, then 10 along Z.
const ROUTE = BotRoute.new({ Vector3.zero, Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) })

describe("BotRoute", function()
	it.each({
		{ Case = "beside the first leg", Point = Vector3.new(5, 0, 3), Progress = 5, Gap = 3 },
		{ Case = "beside the second leg", Point = Vector3.new(12, 0, 6), Progress = 16, Gap = 2 },
		{ Case = "past the end", Point = Vector3.new(10, 0, 15), Progress = 20, Gap = 5 },
		{ Case = "behind the start", Point = Vector3.new(-4, 0, 0), Progress = 0, Gap = 4 },
	})("measures how far along the lane a point is: $Case", function(row)
		local progress, gap = BotRoute.project(ROUTE, row.Point)

		expect(progress).toBeCloseTo(row.Progress)
		expect(gap).toBeCloseTo(row.Gap)
	end)

	it.each({
		{ Case = "on the first leg", Progress = 5, Expected = Vector3.new(5, 0, 0) },
		{ Case = "on the second leg", Progress = 15, Expected = Vector3.new(10, 0, 5) },
		{ Case = "before the start holds at the start", Progress = -3, Expected = Vector3.zero },
		{
			Case = "past the end holds at the end",
			Progress = 99,
			Expected = Vector3.new(10, 0, 10),
		},
	})("finds the point a distance along the lane: $Case", function(row)
		local point = BotRoute.pointAt(ROUTE, row.Progress)

		expect((point - row.Expected).Magnitude).toBeLessThan(0.001)
	end)
end)
