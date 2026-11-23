--!strict

-- Seconds. Attack speed buffs can't push attacks past this rate.
const MIN_ATTACK_INTERVAL = 0.25
-- How much a critical attack deals, as a multiple of a normal one.
const CRIT_MULTIPLIER = 1.75

const UnitTypes = require("./UnitTypes")

type StatModifier = UnitTypes.StatModifier
type UnitStats = UnitTypes.UnitStats

local Module = {}

--[[
	Returns the damage left after armor. Each point of armor adds 1% effective
	health, so 100 armor halves damage and no amount of armor ever blocks it
	all. Negative armor (from armor shred) raises damage, up to double.
]]
function Module.mitigateDamage(amount: number, armor: number): number
	if armor >= 0 then
		return amount * 100 / (100 + armor)
	end

	return amount * (2 - 100 / (100 - armor))
end

--[[
	Returns a unit's stats with its modifiers applied. Each modifier adds to
	the base value first, then all multipliers apply, so two 30% slows stack
	to 49% of the base speed instead of 40%.
]]
function Module.applyModifiers(base: UnitStats, modifiers: { StatModifier }): UnitStats
	local adds: { [string]: number } = {}
	local multipliers: { [string]: number } = {}
	for _, modifier in modifiers do
		adds[modifier.Stat] = (adds[modifier.Stat] or 0) + (modifier.Add or 0)
		multipliers[modifier.Stat] = (multipliers[modifier.Stat] or 1) * (modifier.Multiply or 1)
	end

	local stats = table.clone(base)
	stats.MoveSpeed =
		math.max((base.MoveSpeed + (adds.MoveSpeed or 0)) * (multipliers.MoveSpeed or 1), 0)
	stats.AttackDamage = math.max(
		(base.AttackDamage + (adds.AttackDamage or 0)) * (multipliers.AttackDamage or 1),
		0
	)
	stats.AttackInterval = math.max(
		(base.AttackInterval + (adds.AttackInterval or 0)) * (multipliers.AttackInterval or 1),
		MIN_ATTACK_INTERVAL
	)
	stats.Armor = (base.Armor + (adds.Armor or 0)) * (multipliers.Armor or 1)
	stats.MaxHealth =
		math.max((base.MaxHealth + (adds.MaxHealth or 0)) * (multipliers.MaxHealth or 1), 1)
	stats.AbilityPower = ((base.AbilityPower or 0) + (adds.AbilityPower or 0))
		* (multipliers.AbilityPower or 1)
	stats.AbilityHaste = ((base.AbilityHaste or 0) + (adds.AbilityHaste or 0))
		* (multipliers.AbilityHaste or 1)
	stats.AttackRange =
		math.max((base.AttackRange + (adds.AttackRange or 0)) * (multipliers.AttackRange or 1), 0)
	stats.CritChance = math.clamp(
		((base.CritChance or 0) + (adds.CritChance or 0)) * (multipliers.CritChance or 1),
		0,
		1
	)
	stats.ShieldPower = ((base.ShieldPower or 0) + (adds.ShieldPower or 0))
		* (multipliers.ShieldPower or 1)
	return stats
end

--[[
	Returns a basic attack's damage: a critical hit when roll, a number from
	0 to 1, falls under the attacker's crit chance.
]]
function Module.rollAttackDamage(damage: number, critChance: number?, roll: number): number
	return if roll < (critChance or 0) then damage * CRIT_MULTIPLIER else damage
end

--[[
	Returns ability damage after the caster's ability power, a percent bonus:
	40 ability power makes 100 damage 140.
]]
function Module.amplifyAbilityDamage(amount: number, abilityPower: number?): number
	return amount * (1 + (abilityPower or 0) / 100)
end

return Module
