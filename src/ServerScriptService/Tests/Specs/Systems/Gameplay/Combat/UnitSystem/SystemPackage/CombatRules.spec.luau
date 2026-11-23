--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const CombatRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/CombatRules"
)

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type StatModifier = UnitTypes.StatModifier

-- Round fixture stats, so expected values are easy to check by hand.
const BASE_STATS: UnitTypes.UnitStats = {
	MaxHealth = 500,
	Armor = 20,
	AttackDamage = 50,
	AttackRange = 2,
	AttackInterval = 1,
	MoveSpeed = 10,
	Radius = 1,
}

describe("CombatRules", function()
	it.each({
		{ Case = "no armor changes nothing", Armor = 0, Expected = 100 },
		{ Case = "100 armor halves damage", Armor = 100, Expected = 50 },
		{ Case = "negative armor raises damage", Armor = -100, Expected = 150 },
	})("deals damage after armor: $Case", function(row)
		local dealt = CombatRules.mitigateDamage(100, row.Armor)

		expect(dealt).toBeCloseTo(row.Expected)
	end)

	it("multiplies two slows together instead of adding them", function()
		local slows: { StatModifier } = {
			{ Stat = "MoveSpeed", Multiply = 0.7 },
			{ Stat = "MoveSpeed", Multiply = 0.7 },
		}

		local stats = CombatRules.applyModifiers(BASE_STATS, slows)

		expect(stats.MoveSpeed).toBeCloseTo(4.9)
	end)

	it("adds flat bonuses before multipliers apply", function()
		local modifiers: { StatModifier } = {
			{ Stat = "AttackDamage", Multiply = 0.5 },
			{ Stat = "AttackDamage", Add = 10 },
		}

		local stats = CombatRules.applyModifiers(BASE_STATS, modifiers)

		expect(stats.AttackDamage).toBeCloseTo(30)
	end)

	it("never lets attack speed buffs push attacks faster than every 0.25 seconds", function()
		local surge: { StatModifier } = {
			{ Stat = "AttackInterval", Multiply = 0.1 },
		}

		local stats = CombatRules.applyModifiers(BASE_STATS, surge)

		expect(stats.AttackInterval).toBeCloseTo(0.25)
	end)

	it("counts a stat the unit doesn't list as zero before a bonus adds to it", function()
		local focus: { StatModifier } = {
			{ Stat = "AbilityHaste", Add = 20 },
		}

		local stats = CombatRules.applyModifiers(BASE_STATS, focus)

		expect(stats.AbilityHaste).toBe(20)
	end)

	it.each({
		{
			Case = "a roll under the crit chance hits 1.75 times as hard",
			Roll = 0.1,
			Expected = 175,
		},
		{ Case = "a roll at the crit chance hits normally", Roll = 0.25, Expected = 100 },
	})("rolls critical attacks: $Case", function(row)
		local damage = CombatRules.rollAttackDamage(100, 0.25, row.Roll)

		expect(damage).toBeCloseTo(row.Expected)
	end)

	it("leaves stats no modifier names at their base values", function()
		local slow: { StatModifier } = {
			{ Stat = "MoveSpeed", Multiply = 0.5 },
		}

		local stats = CombatRules.applyModifiers(BASE_STATS, slow)

		expect(stats.Armor).toBe(BASE_STATS.Armor)
		expect(stats.AttackDamage).toBe(BASE_STATS.AttackDamage)
		expect(stats.AttackInterval).toBe(BASE_STATS.AttackInterval)
	end)
end)
