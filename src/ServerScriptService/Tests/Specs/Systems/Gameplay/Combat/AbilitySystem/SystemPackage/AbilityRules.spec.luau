--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const AbilityRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityRules"
)

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)

type ResourceProfile = AbilityTypes.ResourceProfile

-- Fixture profiles with round numbers, so expected values are easy to check
-- by hand.
const MANA: ResourceProfile = {
	Kind = "Mana",
	RegenPerSecond = 4,
	RegenDelay = 0,
	RestoreOnHeroHit = 0,
}
const STAMINA: ResourceProfile = {
	Kind = "Stamina",
	RegenPerSecond = 20,
	RegenDelay = 2,
	RestoreOnHeroHit = 5,
}
const COOLDOWNS_ONLY: ResourceProfile = {
	Kind = "None",
	RegenPerSecond = 0,
	RegenDelay = 0,
	RestoreOnHeroHit = 0,
}

const PROFILES = {
	Mana = MANA,
	Stamina = STAMINA,
	CooldownsOnly = COOLDOWNS_ONLY,
}

describe("AbilityRules", function()
	it.each({
		{
			Case = "mana refills at its rate",
			Profile = "Mana",
			Current = 100,
			SinceSpend = 10,
			Expected = 102,
		},
		{
			Case = "a refill stops at the maximum",
			Profile = "Mana",
			Current = 299,
			SinceSpend = 10,
			Expected = 300,
		},
		{
			Case = "stamina waits after spending",
			Profile = "Stamina",
			Current = 10,
			SinceSpend = 1.9,
			Expected = 10,
		},
		{
			Case = "stamina refills once the wait is over",
			Profile = "Stamina",
			Current = 10,
			SinceSpend = 2,
			Expected = 20,
		},
		{
			Case = "a hero on cooldowns only never changes",
			Profile = "CooldownsOnly",
			Current = 0,
			SinceSpend = 10,
			Expected = 0,
		},
	})("regenerates resources over half a second: $Case", function(row)
		local regenerated =
			AbilityRules.regenerate(PROFILES[row.Profile], row.Current, 300, 0.5, row.SinceSpend)

		expect(regenerated).toBeCloseTo(row.Expected)
	end)

	it.each({
		{ Case = "a mana hero pays the listed cost", Profile = "Mana", Expected = 50 },
		{ Case = "a hero on cooldowns only pays nothing", Profile = "CooldownsOnly", Expected = 0 },
	})("charges for casts: $Case", function(row)
		local cost = AbilityRules.getCost(PROFILES[row.Profile], 50)

		expect(cost).toBe(row.Expected)
	end)

	-- The caster is on Blue in every row.
	it.each({
		{
			Case = "enemy units: an enemy alien",
			Filter = "EnemyUnit",
			Team = "Red",
			Kind = "Minion",
			Expected = true,
		},
		{
			Case = "enemy units: a jungle monster",
			Filter = "EnemyUnit",
			Team = "Neutral",
			Kind = "Monster",
			Expected = true,
		},
		{
			Case = "enemy units: an enemy tower",
			Filter = "EnemyUnit",
			Team = "Red",
			Kind = "Structure",
			Expected = false,
		},
		{
			Case = "enemy units: an enemy ward",
			Filter = "EnemyUnit",
			Team = "Red",
			Kind = "Ward",
			Expected = false,
		},
		{
			Case = "enemy units: an allied alien",
			Filter = "EnemyUnit",
			Team = "Blue",
			Kind = "Minion",
			Expected = false,
		},
		{
			Case = "enemy heroes: an enemy hero",
			Filter = "EnemyHero",
			Team = "Red",
			Kind = "Hero",
			Expected = true,
		},
		{
			Case = "enemy heroes: an enemy alien",
			Filter = "EnemyHero",
			Team = "Red",
			Kind = "Minion",
			Expected = false,
		},
		{
			Case = "enemy non-heroes: an enemy alien",
			Filter = "EnemyNonHero",
			Team = "Red",
			Kind = "Minion",
			Expected = true,
		},
		{
			Case = "enemy non-heroes: an enemy hero",
			Filter = "EnemyNonHero",
			Team = "Red",
			Kind = "Hero",
			Expected = false,
		},
		{
			Case = "allied units: an allied tower",
			Filter = "AllyUnit",
			Team = "Blue",
			Kind = "Structure",
			Expected = true,
		},
		{
			Case = "allied units: an allied hero",
			Filter = "AllyUnit",
			Team = "Blue",
			Kind = "Hero",
			Expected = false,
		},
		{
			Case = "allied units: an enemy tower",
			Filter = "AllyUnit",
			Team = "Red",
			Kind = "Structure",
			Expected = false,
		},
	})("decides who an ability can hit: $Case", function(row)
		local matches = AbilityRules.matchesFilter("Blue", row.Team, row.Kind, row.Filter)

		expect(matches).toBe(row.Expected)
	end)

	it.each({
		{
			Case = "a point past the range is pulled back along the same line",
			Point = Vector3.new(0, 0, -20),
			ExpectedAim = Vector3.new(0, 0, -8),
			ExpectedDirection = Vector3.new(0, 0, -1),
		},
		{
			Case = "a point within range stays where it is",
			Point = Vector3.new(3, 0, 4),
			ExpectedAim = Vector3.new(3, 0, 4),
			ExpectedDirection = Vector3.new(0.6, 0, 0.8),
		},
		{
			Case = "aiming at the caster's own spot uses the fallback direction",
			Point = Vector3.zero,
			ExpectedAim = Vector3.zero,
			ExpectedDirection = Vector3.xAxis,
		},
	})("clamps aim to an 8 stud range: $Case", function(row)
		local aim, direction = AbilityRules.clampAim(Vector3.zero, row.Point, 8, Vector3.xAxis)

		expect((aim - row.ExpectedAim).Magnitude).toBeLessThan(0.001)
		expect((direction - row.ExpectedDirection).Magnitude).toBeLessThan(0.001)
	end)
end)
