--!strict

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)

export type AbilityEntry = {
	Name: string,
	Description: string,
	-- Seconds.
	Cooldown: number,
	-- Paid from the hero's resource. Heroes on cooldowns only pay nothing.
	Cost: number,
	Targeting: AbilityTypes.Targeting,
	-- Studs from the caster's edge.
	Range: number,
	TargetFilter: AbilityTypes.TargetFilter?,
	-- Named tuning numbers the ability's handler reads.
	Values: AbilityTypes.AbilityValues,
}

local Module = {}

-- Every ability's numbers live here, so balance changes never touch code.
-- Distances are studs, times are seconds, and multipliers apply to the
-- named stat.
Module.Abilities = {
	["Haru.Q"] = {
		Name = "Echo Clone",
		Description = "Leaves a clone. While it stands, Haru's attacks near it strike twice.",
		Cooldown = 8,
		Cost = 40,
		Targeting = "Point",
		Range = 9,
		Values = { Duration = 5, EchoDamage = 25, EchoRange = 12 },
	},
	["Haru.W"] = {
		Name = "Spiral Strike",
		Description = "Dashes to a spot and blasts enemies around it.",
		Cooldown = 10,
		Cost = 50,
		Targeting = "Point",
		Range = 9,
		Values = { Damage = 80, Radius = 5, DashSpeed = 55 },
	},
	["Haru.E"] = {
		Name = "Leaf Step",
		Description = "Swaps places with the clone.",
		Cooldown = 14,
		Cost = 30,
		Targeting = "Self",
		Range = 0,
		Values = {},
	},
	["Haru.R"] = {
		Name = "Echo Storm",
		Description = "Clones surround an enemy and strike it three times.",
		Cooldown = 60,
		Cost = 50,
		Targeting = "Unit",
		Range = 10,
		TargetFilter = "EnemyUnit",
		Values = { Strikes = 3, StrikeDamage = 60, StrikeInterval = 0.25, RingRadius = 4 },
	},
	["Ryuka.Q"] = {
		Name = "Ki Volley",
		Description = "Fires a ki blast that hits the first enemy in its path.",
		Cooldown = 6,
		Cost = 50,
		Targeting = "Direction",
		Range = 28,
		Values = { Damage = 90, Speed = 70, Width = 2.5 },
	},
	["Ryuka.W"] = {
		Name = "Power Surge",
		Description = "Attacks faster and moves a little faster for a few seconds.",
		Cooldown = 14,
		Cost = 40,
		Targeting = "Self",
		Range = 0,
		Values = { Duration = 5, AttackIntervalMultiplier = 0.7, MoveSpeedMultiplier = 1.1 },
	},
	["Ryuka.E"] = {
		Name = "Flash Step",
		Description = "Dashes a short distance.",
		Cooldown = 16,
		Cost = 60,
		Targeting = "Point",
		Range = 7,
		Values = { DashSpeed = 60 },
	},
	["Ryuka.R"] = {
		Name = "Celestial Beam",
		Description = "Roots Ryuka to charge, then fires a beam down the whole line.",
		Cooldown = 70,
		Cost = 100,
		Targeting = "Direction",
		Range = 60,
		Values = { ChannelTime = 1, Damage = 260, Width = 4 },
	},
	["Spell.Blink"] = {
		Name = "Blink",
		Description = "Teleports a short distance.",
		Cooldown = 300,
		Cost = 0,
		Targeting = "Point",
		Range = 8,
		Values = {},
	},
	["Spell.Mend"] = {
		Name = "Mend",
		Description = "Heals you and the most hurt ally nearby, with a burst of speed.",
		Cooldown = 240,
		Cost = 0,
		Targeting = "Self",
		Range = 0,
		Values = { HealShare = 0.25, AllyRange = 15, SpeedMultiplier = 1.2, SpeedDuration = 2 },
	},
	["Spell.Scorch"] = {
		Name = "Scorch",
		Description = "Burns an enemy hero and cuts their healing.",
		Cooldown = 180,
		Cost = 0,
		Targeting = "Unit",
		Range = 12,
		TargetFilter = "EnemyHero",
		Values = { DamagePerSecond = 20, Duration = 5 },
	},
	["Spell.Hunt"] = {
		Name = "Hunt",
		Description = "Deals heavy true damage to an alien or monster.",
		Cooldown = 90,
		Cost = 0,
		Targeting = "Unit",
		Range = 6,
		TargetFilter = "EnemyNonHero",
		Values = { Damage = 400 },
	},
	["Spell.Warp"] = {
		Name = "Warp",
		Description = "Channels, then teleports next to an allied tower or alien.",
		Cooldown = 360,
		Cost = 0,
		Targeting = "Unit",
		Range = 2000,
		TargetFilter = "AllyUnit",
		Values = { ChannelTime = 4, LandingOffset = 6 },
	},
	["Spell.Drain"] = {
		Name = "Drain",
		Description = "Slows an enemy hero and weakens their attacks.",
		Cooldown = 210,
		Cost = 0,
		Targeting = "Unit",
		Range = 10,
		TargetFilter = "EnemyHero",
		Values = { Duration = 3, SlowMultiplier = 0.6, DamageMultiplier = 0.65 },
	},
	["Spell.Purify"] = {
		Name = "Purify",
		Description = "Removes stuns, roots, and slows, and resists them briefly.",
		Cooldown = 210,
		Cost = 0,
		Targeting = "Self",
		Range = 0,
		Values = { ImmunityDuration = 1.5 },
	},
	Recall = {
		Name = "Recall",
		Description = "After a few seconds standing still, returns to the fountain.",
		Cooldown = 0,
		Cost = 0,
		Targeting = "Self",
		Range = 0,
		Values = { ChannelTime = 8 },
	},
} :: { [string]: AbilityEntry }

return Module
