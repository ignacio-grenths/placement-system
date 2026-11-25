--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const MinionWaveRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MinionWaveSystem/SystemPackage/MinionWaveRules"
)

-- The game's timing: the first wave at 1:00, then one every 30 seconds.
const SCHEDULE = {
	FirstWaveTime = 60,
	Interval = 30,
}

local function countRole(
	roles: { MinionWaveRules.MinionRole },
	role: MinionWaveRules.MinionRole
): number
	local count = 0
	for _, entry in roles do
		if entry == role then
			count += 1
		end
	end
	return count
end

describe("MinionWaveRules", function()
	it.each({
		{ Case = "just before the first wave", Elapsed = 59.9, Expected = 0 },
		{ Case = "the moment the first wave leaves", Elapsed = 60, Expected = 1 },
		{ Case = "just before the second wave", Elapsed = 89.9, Expected = 1 },
		{ Case = "the moment the second wave leaves", Elapsed = 90, Expected = 2 },
	})("counts the waves sent by match time: $Case", function(row)
		local count = MinionWaveRules.getWaveCount(SCHEDULE, row.Elapsed)

		expect(count).toBe(row.Expected)
	end)

	it("sends three melee, two archers, and one caster in a plain wave", function()
		local roles = MinionWaveRules.getComposition(1, false)

		expect(countRole(roles, "Melee")).toBe(3)
		expect(countRole(roles, "Archer")).toBe(2)
		expect(countRole(roles, "Caster")).toBe(1)
		expect(countRole(roles, "Siege")).toBe(0)
		expect(countRole(roles, "Super")).toBe(0)
	end)

	it.each({
		{ Case = "wave 2 has none", Wave = 2, Expected = 0 },
		{ Case = "wave 3 has one", Wave = 3, Expected = 1 },
	})("adds a siege minion on every third wave: $Case", function(row)
		local roles = MinionWaveRules.getComposition(row.Wave, false)

		expect(countRole(roles, "Siege")).toBe(row.Expected)
	end)

	it("leads the wave with a super minion while the enemy gate is down", function()
		local roles = MinionWaveRules.getComposition(1, true)

		expect(roles[1]).toBe("Super")
		expect(countRole(roles, "Super")).toBe(1)
	end)
end)
