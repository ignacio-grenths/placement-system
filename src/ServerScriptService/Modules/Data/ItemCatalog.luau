--!strict

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

-- Stat items change the hero's stats while held. Boots are a stat item a
-- hero can hold only one of. A consumable is used from its slot, then gone.
export type ItemKind = "Stat" | "Boots" | "Consumable"

export type ItemEntry = {
	Name: string,
	Description: string,
	Cost: number,
	Kind: ItemKind,
	-- Changes while held, for Stat and Boots items.
	Stats: { UnitTypes.StatModifier },
	-- Health a consumable restores over HealDuration seconds.
	HealAmount: number?,
	HealDuration: number?,
	-- The item this one upgrades: buying it replaces that item, which the
	-- hero must hold.
	UpgradeOf: string?,
	-- The PairBonuses key of the pair this item belongs to.
	Pair: string?,
	-- Shop order, lowest first.
	Order: number,
}

export type PairBonus = {
	Name: string,
	Description: string,
	-- Both items must be held for the bonus.
	Items: { string },
	-- Which bonus wins when a hero completes two at once, lowest first.
	Order: number,
}

local Module = {}

-- No recipe trees: every item is bought whole. Pair items are good alone,
-- and holding both of a pair unlocks its bonus.
Module.Items = {
	HealthPotion = {
		Name = "Health Potion",
		Description = "Restores 120 health over 10 seconds.",
		Cost = 50,
		Kind = "Consumable",
		Stats = {},
		HealAmount = 120,
		HealDuration = 10,
		Order = 1,
	},
	Boots = {
		Name = "Boots",
		Description = "Move faster.",
		Cost = 300,
		Kind = "Boots",
		Stats = { { Stat = "MoveSpeed", Add = 2 } },
		Order = 2,
	},
	SwiftBoots = {
		Name = "Swift Boots",
		Description = "Upgrades Boots: move much faster.",
		Cost = 500,
		Kind = "Boots",
		Stats = { { Stat = "MoveSpeed", Add = 4 } },
		UpgradeOf = "Boots",
		Order = 3,
	},
	BeetleCarapace = {
		Name = "Beetle Carapace",
		Description = "Armor. Attackers take back some of the damage they deal you.",
		Cost = 950,
		Kind = "Stat",
		Stats = { { Stat = "Armor", Add = 35 } },
		Order = 4,
	},
	VoidShard = {
		Name = "Void Shard",
		Description = "Ability power. Abilities cut the healing of heroes they hit.",
		Cost = 1050,
		Kind = "Stat",
		Stats = { { Stat = "AbilityPower", Add = 15 } },
		Order = 5,
	},
	StarfallPendant = {
		Name = "Starfall Pendant",
		Description = "Armor and health. A shield catches you when you drop low.",
		Cost = 1000,
		Kind = "Stat",
		Stats = { { Stat = "Armor", Add = 20 }, { Stat = "MaxHealth", Add = 100 } },
		Order = 6,
	},
	GrubHammer = {
		Name = "Grub Hammer",
		Description = "Attack damage. Hits harder against towers.",
		Cost = 1100,
		Kind = "Stat",
		Stats = { { Stat = "AttackDamage", Add = 25 } },
		Pair = "WreckingCrew",
		Order = 7,
	},
	HullPlating = {
		Name = "Hull Plating",
		Description = "Armor and health.",
		Cost = 1000,
		Kind = "Stat",
		Stats = { { Stat = "Armor", Add = 25 }, { Stat = "MaxHealth", Add = 150 } },
		Pair = "WreckingCrew",
		Order = 8,
	},
	BountyScope = {
		Name = "Bounty Scope",
		Description = "Attack damage, critical hits, and a little more reach.",
		Cost = 1150,
		Kind = "Stat",
		Stats = {
			{ Stat = "AttackDamage", Add = 12 },
			{ Stat = "CritChance", Add = 0.2 },
			{ Stat = "AttackRange", Add = 1 },
		},
		Pair = "BountyHunter",
		Order = 9,
	},
	TrackersCloak = {
		Name = "Tracker's Cloak",
		Description = "Move faster, and faster still out of combat.",
		Cost = 900,
		Kind = "Stat",
		Stats = { { Stat = "MoveSpeed", Add = 1 } },
		Pair = "BountyHunter",
		Order = 10,
	},
	TitanAegis = {
		Name = "Titan Aegis",
		Description = "Health, and the shields you cast are stronger.",
		Cost = 1100,
		Kind = "Stat",
		Stats = { { Stat = "MaxHealth", Add = 250 }, { Stat = "ShieldPower", Add = 20 } },
		Pair = "LastStand",
		Order = 11,
	},
	MendersCharm = {
		Name = "Mender's Charm",
		Description = "Stronger shields and faster cooldowns.",
		Cost = 950,
		Kind = "Stat",
		Stats = { { Stat = "ShieldPower", Add = 15 }, { Stat = "AbilityHaste", Add = 15 } },
		Pair = "LastStand",
		Order = 12,
	},
	KiConduit = {
		Name = "Ki Conduit",
		Description = "Ability power and a little faster cooldowns.",
		Cost = 1100,
		Kind = "Stat",
		Stats = { { Stat = "AbilityPower", Add = 20 }, { Stat = "AbilityHaste", Add = 5 } },
		Pair = "Spellstrike",
		Order = 13,
	},
	EchoBlade = {
		Name = "Echo Blade",
		Description = "Attack damage and faster attacks.",
		Cost = 1200,
		Kind = "Stat",
		Stats = {
			{ Stat = "AttackDamage", Add = 15 },
			{ Stat = "AttackInterval", Multiply = 0.85 },
		},
		Pair = "Spellstrike",
		Order = 14,
	},
} :: { [string]: ItemEntry }

-- Only one pair bonus is active at a time, so choosing a pair is a
-- commitment: the first pair a hero completes stays its bonus.
Module.PairBonuses = {
	WreckingCrew = {
		Name = "Wrecking Crew",
		Description = "Hit a tower and your aliens nearby deal 50% more damage to it.",
		Items = { "GrubHammer", "HullPlating" },
		Order = 1,
	},
	BountyHunter = {
		Name = "Bounty Hunter",
		Description = "Hero takedowns pay 50% more gold.",
		Items = { "BountyScope", "TrackersCloak" },
		Order = 2,
	},
	LastStand = {
		Name = "Last Stand",
		Description = "A shield on an ally under 30% health is doubled, once every 20 seconds.",
		Items = { "TitanAegis", "MendersCharm" },
		Order = 3,
	},
	Spellstrike = {
		Name = "Spellstrike",
		Description = "After an ability, your next attack hits harder and cools it down 10%.",
		Items = { "KiConduit", "EchoBlade" },
		Order = 4,
	},
} :: { [string]: PairBonus }

-- The numbers behind item and pair passives.
Module.Effects = {
	-- Share of a basic attack's damage that Beetle Carapace sends back.
	CarapaceReflectShare = 0.15,
	VoidShardHealingCutSeconds = 3,
	-- Starfall Pendant's shield when the holder drops under the threshold
	-- share of max health, and the seconds before it can catch them again.
	PendantShield = 200,
	PendantShieldSeconds = 3,
	PendantThreshold = 0.3,
	PendantCooldown = 60,
	-- Grub Hammer's extra damage to structures, as a share of each hit.
	HammerStructureShare = 0.2,
	-- Tracker's Cloak: seconds without fighting before the extra speed.
	CloakIdleSeconds = 4,
	CloakMoveSpeed = 3,
	-- Wrecking Crew: studs around the hero and seconds after its last hit
	-- on a tower that allied aliens deal the extra share of damage to it.
	WreckingRadius = 20,
	WreckingSeconds = 4,
	WreckingShare = 0.5,
	BountyGoldMultiplier = 1.5,
	LastStandThreshold = 0.3,
	LastStandCooldown = 20,
	-- Spellstrike: seconds the empowered attack waits after a cast, its
	-- damage (flat plus a share of attack damage), and the share of the
	-- ability's cooldown it refunds.
	SpellstrikeSeconds = 6,
	SpellstrikeDamage = 25,
	SpellstrikeAttackShare = 0.4,
	SpellstrikeRefundShare = 0.1,
}

-- How many items a hero can carry.
Module.InventorySize = 6

return Module
