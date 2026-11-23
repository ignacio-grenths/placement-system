--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const HeroLevelRules = require(
	"@game/ServerScriptService/Modules/Systems/Progression/HeroLevelSystem/SystemPackage/HeroLevelRules"
)

-- A short fixture curve: level 4 is the top, reached at 280 + 380 + 480 XP.
const XP_PER_LEVEL = { 280, 380, 480 }

const RANK_RULES: HeroLevelRules.RankRules = {
	MaxBasicRank = 4,
	MaxUltimateRank = 3,
	UltimateLevels = { 6, 10, 14 },
}

describe("HeroLevelRules", function()
	it.each({
		{ Case = "just short of level 2", Xp = 279, Level = 1, Into = 279, Next = 280 },
		{ Case = "exactly enough for level 2", Xp = 280, Level = 2, Into = 0, Next = 380 },
		{
			Case = "leftover experience carries into the level",
			Xp = 700,
			Level = 3,
			Into = 40,
			Next = 480,
		},
		{
			Case = "experience past the top level stays at the top",
			Xp = 5000,
			Level = 4,
			Into = 0,
			Next = 0,
		},
	})("turns experience into a level: $Case", function(row)
		local level, into, nextNeeded = HeroLevelRules.getLevel(XP_PER_LEVEL, row.Xp)

		expect(level).toBe(row.Level)
		expect(into).toBe(row.Into)
		expect(nextNeeded).toBe(row.Next)
	end)

	it.each({
		{ Case = "R is locked before level 6", Slot = "R", Rank = 0, Level = 5, Expected = false },
		{ Case = "R opens at level 6", Slot = "R", Rank = 0, Level = 6, Expected = true },
		{
			Case = "R's second rank waits for level 10",
			Slot = "R",
			Rank = 1,
			Level = 9,
			Expected = false,
		},
		{ Case = "R stops at its last rank", Slot = "R", Rank = 3, Level = 15, Expected = false },
		{
			Case = "a basic ability can't pass half the level",
			Slot = "Q",
			Rank = 1,
			Level = 2,
			Expected = false,
		},
		{
			Case = "a basic ability can rank once the level allows",
			Slot = "Q",
			Rank = 1,
			Level = 3,
			Expected = true,
		},
		{
			Case = "a basic ability stops at its last rank",
			Slot = "Q",
			Rank = 4,
			Level = 15,
			Expected = false,
		},
	})("decides when an ability can rank up: $Case", function(row)
		local canRank =
			HeroLevelRules.canRankUp(row.Slot, { [row.Slot] = row.Rank }, row.Level, RANK_RULES)

		expect(canRank).toBe(row.Expected)
	end)

	it.each({
		{ Case = "a point for each level not spent", Level = 3, Expected = 1 },
		{ Case = "no points once every level is spent", Level = 2, Expected = 0 },
	})("counts unspent points: $Case", function(row)
		local points = HeroLevelRules.getUnspentPoints({ Q = 1, W = 1 }, row.Level)

		expect(points).toBe(row.Expected)
	end)

	it.each({
		{
			Case = "R comes first whenever it can rank",
			Order = { "Q", "W", "E" },
			Ranks = { Q = 3, W = 2, E = 0, R = 0 },
			Level = 6,
			Expected = "R",
		},
		{
			Case = "otherwise the first ability in the hero's order",
			Order = { "W", "Q", "E" },
			Ranks = { Q = 0, W = 0, E = 0, R = 0 },
			Level = 1,
			Expected = "W",
		},
		{
			Case = "an ability the level holds back is skipped for the next",
			Order = { "Q", "W", "E" },
			Ranks = { Q = 1, W = 0, E = 0, R = 0 },
			Level = 2,
			Expected = "W",
		},
	})("picks the automatic rank-up: $Case", function(row)
		local slot = HeroLevelRules.chooseAutoRank(row.Order, row.Ranks, row.Level, RANK_RULES)

		expect(slot).toBe(row.Expected)
	end)

	it.each({
		{ Case = "a lone hero takes it all", Sharers = 1, Expected = 300 },
		{ Case = "two heroes each take more than half", Sharers = 2, Expected = 195 },
		{ Case = "nobody near takes nothing", Sharers = 0, Expected = 0 },
	})("splits shared experience with a bonus: $Case", function(row)
		-- 300 experience, and each extra hero adds 30% to the pool.
		local share = HeroLevelRules.getXpShare(300, row.Sharers, 0.3)

		expect(share).toBeCloseTo(row.Expected, 5)
	end)

	it("picks nothing when no ability can rank up", function()
		local slot = HeroLevelRules.chooseAutoRank(
			{ "Q", "W", "E" },
			{ Q = 1, W = 1, E = 1, R = 0 },
			1,
			RANK_RULES
		)

		expect(slot).toBeNil()
	end)
end)
