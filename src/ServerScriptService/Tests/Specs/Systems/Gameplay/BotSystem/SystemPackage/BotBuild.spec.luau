--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const BotBuild =
	require("@game/ServerScriptService/Modules/Systems/Gameplay/BotSystem/SystemPackage/BotBuild")

-- A fixture shop: Swift Boots upgrade Boots; the rest stand alone.
const UPGRADES_OF: { [string]: string? } = { SwiftBoots = "Boots" }
const ORDER = { "Boots", "SwiftBoots", "Blade", "Shield" }

type NextRow = {
	Case: string,
	Inventory: { string },
	Expected: string?,
}

describe("BotBuild", function()
	it("puts each upgrade's base item just before it", function()
		local order = BotBuild.expand({ "SwiftBoots", "Blade" }, UPGRADES_OF)

		expect(order).toEqual({ "Boots", "SwiftBoots", "Blade" })
	end)

	local rows: { NextRow } = {
		{
			Case = "an empty bag starts the build",
			Inventory = { "", "", "" },
			Expected = "Boots",
		},
		{
			Case = "a held item is skipped",
			Inventory = { "Boots", "", "" },
			Expected = "SwiftBoots",
		},
		{
			Case = "a held upgrade covers its base item",
			Inventory = { "SwiftBoots", "", "" },
			Expected = "Blade",
		},
		{
			Case = "a finished build wants nothing",
			Inventory = { "SwiftBoots", "Blade", "Shield" },
			Expected = nil,
		},
	}

	it.each(rows)("picks the next item to buy: $Case", function(row: NextRow)
		local nextItem = BotBuild.getNextItem(row.Inventory, ORDER, UPGRADES_OF)

		expect(nextItem).toBe(row.Expected)
	end)
end)
