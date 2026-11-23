--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const BalanceReport = require(
	"@game/ServerScriptService/Modules/Systems/Tooling/BalanceSystem/SystemPackage/BalanceReport"
)

type HeroLine = BalanceReport.HeroLine

local function line(
	team: string,
	hero: string,
	kills: number,
	deaths: number,
	level: number,
	damage: number
): HeroLine
	return {
		Team = team,
		Role = "Mid",
		Hero = hero,
		Kills = kills,
		Deaths = deaths,
		Level = level,
		HeroDamage = damage,
	}
end

-- Two decided matches and one that ran out of time. Haru plays three
-- times (once on each side of the second match) and Ryuka once.
const REPORTS: { BalanceReport.MatchReport } = {
	{
		Winner = "Blue",
		Minutes = 20,
		Heroes = { line("Blue", "Haru", 3, 1, 10, 1000), line("Red", "Ryuka", 1, 3, 8, 600) },
		Structures = {},
		Bosses = {},
	},
	{
		Winner = "Red",
		Minutes = 30,
		Heroes = { line("Blue", "Haru", 0, 2, 12, 400), line("Red", "Haru", 2, 0, 14, 800) },
		Structures = {},
		Bosses = {},
	},
	{
		Winner = "None",
		Minutes = 45,
		Heroes = { line("Blue", "Ryuka", 5, 0, 15, 2000) },
		Structures = {},
		Bosses = {},
	},
}

describe("BalanceReport", function()
	it("counts side wins and match length over decided matches only", function()
		local summary = BalanceReport.summarize(REPORTS)

		expect(summary.Matches).toBe(2)
		expect(summary.TimedOut).toBe(1)
		expect(summary.BlueWinRate).toBe(0.5)
		expect(summary.AverageMinutes).toBe(25)
	end)

	it("gives each hero its win rate and average line, best first", function()
		local summary = BalanceReport.summarize(REPORTS)
		local haru = summary.Heroes[1]
		local ryuka = summary.Heroes[2]

		expect(haru.Hero).toBe("Haru")
		expect(haru.Games).toBe(3)
		expect(haru.WinRate).toBeCloseTo(2 / 3, 5)
		expect(haru.Deaths).toBe(1)
		expect(haru.Level).toBe(12)
		expect(ryuka.Hero).toBe("Ryuka")
		expect(ryuka.Games).toBe(1)
		expect(ryuka.WinRate).toBe(0)
	end)
end)
