--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const ItemRules = require(
	"@game/ServerScriptService/Modules/Systems/Economy/ItemShopSystem/SystemPackage/ItemRules"
)

-- A fixture list of pairs, so the rule doesn't depend on the real catalog.
const PAIRS: { ItemRules.Pair } = {
	{ Id = "Anvil", Items = { "Hammer", "Plate" } },
	{ Id = "Bounty", Items = { "Scope", "Cloak" } },
}

type PairRow = {
	Case: string,
	Inventory: { string },
	Current: string?,
	Expected: string?,
}

describe("ItemRules", function()
	local rows: { PairRow } = {
		{
			Case = "one item of a pair earns nothing",
			Inventory = { "Hammer", "", "" },
			Current = nil,
			Expected = nil,
		},
		{
			Case = "both items of a pair earn its bonus",
			Inventory = { "Plate", "Hammer", "" },
			Current = nil,
			Expected = "Anvil",
		},
		{
			Case = "completing a second pair keeps the first bonus",
			Inventory = { "Scope", "Cloak", "Hammer", "Plate" },
			Current = "Bounty",
			Expected = "Bounty",
		},
		{
			Case = "a broken pair gives way to another complete one",
			Inventory = { "Scope", "Cloak", "", "" },
			Current = "Anvil",
			Expected = "Bounty",
		},
	}

	it.each(rows)("picks the active pair bonus: $Case", function(row: PairRow)
		local active = ItemRules.getActivePair(row.Inventory, PAIRS, row.Current)

		expect(active).toBe(row.Expected)
	end)
end)
