--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const CombatRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/CombatRules"
)

describe("CombatRules", function()
	it.each({
		{ Case = "no armor changes nothing", Armor = 0, Expected = 100 },
		{ Case = "100 armor halves damage", Armor = 100, Expected = 50 },
		{ Case = "negative armor raises damage", Armor = -100, Expected = 150 },
	})("deals damage after armor: $Case", function(row)
		local dealt = CombatRules.mitigateDamage(100, row.Armor)

		expect(dealt).toBeCloseTo(row.Expected)
	end)
end)
