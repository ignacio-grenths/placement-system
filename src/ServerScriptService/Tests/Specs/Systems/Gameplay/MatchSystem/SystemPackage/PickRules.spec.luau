--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const PickRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/PickRules"
)

const MatchTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchTypes"
)

type Pick = MatchTypes.Pick
type Team = MatchTypes.Team

-- A fixture pool, so the rules don't depend on the real catalog.
const POOL: { MatchTypes.PoolHero } = {
	{ HeroId = "MidA", Role = "Mid" },
	{ HeroId = "TopA", Role = "Top" },
	{ HeroId = "MidB", Role = "Mid" },
	{ HeroId = "TopB", Role = "Top" },
}

local function makePick(userId: number, team: Team, heroId: string, isLockedIn: boolean): Pick
	return {
		UserId = userId,
		Name = `Player{userId}`,
		Team = team,
		HeroId = heroId,
		IsLockedIn = isLockedIn,
	}
end

type OpenRow = {
	Case: string,
	Other: Pick,
	HeroId: string,
	Expected: boolean,
}

type ResolveRow = {
	Case: string,
	Picks: { Pick },
	Expected: { string },
}

describe("PickRules", function()
	local openRows: { OpenRow } = {
		{
			Case = "a hero outside the pool is refused",
			Other = makePick(2, "Red", "", false),
			HeroId = "Unknown",
			Expected = false,
		},
		{
			Case = "a teammate's locked hero blocks its role",
			Other = makePick(2, "Blue", "MidA", true),
			HeroId = "MidB",
			Expected = false,
		},
		{
			Case = "a teammate only hovering blocks nothing",
			Other = makePick(2, "Blue", "MidA", false),
			HeroId = "MidA",
			Expected = true,
		},
		{
			Case = "an enemy's lock of the role blocks nothing",
			Other = makePick(2, "Red", "MidA", true),
			HeroId = "MidA",
			Expected = true,
		},
	}

	it.each(openRows)("decides whether a hero can be taken: $Case", function(row: OpenRow)
		local pick = makePick(1, "Blue", "", false)

		local isOpen = PickRules.isHeroOpen({ pick, row.Other }, POOL, pick, row.HeroId)

		expect(isOpen).toBe(row.Expected)
	end)

	local resolveRows: { ResolveRow } = {
		{
			Case = "a lock beats an earlier teammate's hover of its role",
			Picks = { makePick(1, "Blue", "MidA", false), makePick(2, "Blue", "MidB", true) },
			Expected = { "TopA", "MidB" },
		},
		{
			Case = "the earlier of two teammates hovering one role keeps it",
			Picks = { makePick(1, "Blue", "MidB", false), makePick(2, "Blue", "MidA", false) },
			Expected = { "MidB", "TopA" },
		},
		{
			Case = "a player with no pick gets the first role left after hovers",
			Picks = { makePick(1, "Blue", "", false), makePick(2, "Blue", "MidA", false) },
			Expected = { "TopA", "MidA" },
		},
		{
			Case = "each team fills its roles on its own",
			Picks = { makePick(1, "Blue", "MidA", true), makePick(2, "Red", "MidA", false) },
			Expected = { "MidA", "MidA" },
		},
	}

	it.each(resolveRows)("gives every pick a hero: $Case", function(row: ResolveRow)
		local assignments = PickRules.resolve(row.Picks, POOL)

		local heroIds = {}
		for _, assignment in assignments do
			table.insert(heroIds, assignment.HeroId)
		end
		expect(heroIds).toEqual(row.Expected)
	end)
end)
