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
	-- Shop order, lowest first.
	Order: number,
}

local Module = {}

-- The first shop. The item pairs and their bonuses arrive in milestone 2.
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
	BeetleCarapace = {
		Name = "Beetle Carapace",
		Description = "A lot of armor.",
		Cost = 900,
		Kind = "Stat",
		Stats = { { Stat = "Armor", Add = 40 } },
		Order = 3,
	},
	HullPlating = {
		Name = "Hull Plating",
		Description = "Armor and health.",
		Cost = 1000,
		Kind = "Stat",
		Stats = { { Stat = "Armor", Add = 25 }, { Stat = "MaxHealth", Add = 150 } },
		Order = 4,
	},
	GrubHammer = {
		Name = "Grub Hammer",
		Description = "Hit harder.",
		Cost = 1100,
		Kind = "Stat",
		Stats = { { Stat = "AttackDamage", Add = 25 } },
		Order = 5,
	},
	KiConduit = {
		Name = "Ki Conduit",
		Description = "Abilities deal 20% more damage.",
		Cost = 1100,
		Kind = "Stat",
		Stats = { { Stat = "AbilityPower", Add = 20 } },
		Order = 6,
	},
	BountyScope = {
		Name = "Bounty Scope",
		Description = "Attack damage and a little speed.",
		Cost = 1150,
		Kind = "Stat",
		Stats = { { Stat = "AttackDamage", Add = 18 }, { Stat = "MoveSpeed", Add = 1 } },
		Order = 7,
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
		Order = 8,
	},
} :: { [string]: ItemEntry }

-- How many items a hero can carry.
Module.InventorySize = 6

return Module
