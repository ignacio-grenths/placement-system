--!strict

export type Team = "Blue" | "Red" | "Neutral"
-- A summon is a short-lived helper, like a clone, that fights for its owner.
export type UnitKind = "Hero" | "Minion" | "Monster" | "Structure" | "Summon"
-- Attack and Ability damage are reduced by armor; True damage is not.
export type DamageKind = "Attack" | "Ability" | "True"
export type StatName =
	"MoveSpeed"
	| "AttackDamage"
	| "AttackInterval"
	| "Armor"
	| "MaxHealth"
	| "AbilityPower"
	| "AbilityHaste"

export type UnitStats = {
	MaxHealth: number,
	Armor: number,
	AttackDamage: number,
	-- Studs from the attacker's edge to the target's edge.
	AttackRange: number,
	-- Seconds between two attacks.
	AttackInterval: number,
	-- Studs per second. Zero for units that never move.
	MoveSpeed: number,
	Radius: number,
	-- Studs per second. Nil for melee attacks, which land at once.
	ProjectileSpeed: number?,
	-- Percent added to the unit's ability damage. Nil counts as 0.
	AbilityPower: number?,
	-- Shortens cooldowns: 20 haste makes them 100 / 120 as long. Nil is 0.
	AbilityHaste: number?,
}

-- Changes one stat: Add applies to the base value first, then Multiply.
export type StatModifier = {
	Stat: StatName,
	Add: number?,
	Multiply: number?,
}

export type TimedModifier = {
	Modifier: StatModifier,
	-- os.clock() time the modifier ends. math.huge for a permanent one,
	-- such as an item's, which survives death.
	ExpiresAt: number,
}

export type Dash = {
	Destination: Vector3,
	-- Studs per second.
	Speed: number,
	OnArrive: ((Unit) -> ())?,
}

export type Order =
	{ Kind: "Idle" }
	| { Kind: "Move", Target: Vector3 }
	| { Kind: "Attack", TargetId: number }

export type Unit = {
	Id: number,
	Kind: UnitKind,
	TypeId: string,
	Team: Team,
	-- Stats before modifiers. Stats holds the values in effect.
	BaseStats: UnitStats,
	Stats: UnitStats,
	Modifiers: { [string]: TimedModifier },
	-- Always on the ground plane, so Y is zero.
	Position: Vector3,
	-- Radians around the vertical axis. Zero faces along -Z.
	Facing: number,
	-- Counts teleports (mod 256), so clients jump instead of sliding.
	MoveEpoch: number,
	Health: number,
	Shield: number,
	ShieldExpiresAt: number,
	Resource: number,
	MaxResource: number,
	IsDead: boolean,
	IsRemoved: boolean,
	IsTargetable: boolean,
	-- Set by whatever runs a channel (a recall, a charged beam), so brains
	-- leave the unit's orders alone meanwhile.
	IsChanneling: boolean,
	RemoveOnDeath: boolean,
	OwnerPlayer: Player?,
	Order: Order,
	-- Waypoints around walls toward PathGoal, the last one the goal itself.
	Path: { Vector3 }?,
	PathGoal: Vector3?,
	-- os.clock() time the path is found again, since its goal may move.
	NextPathTime: number,
	Dash: Dash?,
	-- os.clock() times that crowd control and its immunity end.
	StunnedUntil: number,
	RootedUntil: number,
	CrowdControlImmuneUntil: number,
	HealingCutUntil: number,
	-- Seconds until the unit can attack again.
	AttackCooldown: number,
	Brain: ((Unit) -> ())?,
	NextThinkTime: number,
}

-- What clients learn about a unit once, when it appears.
export type UnitInfo = {
	Id: number,
	Kind: UnitKind,
	TypeId: string,
	Team: Team,
	Radius: number,
	Position: Vector3,
	Health: number,
	MaxHealth: number,
	OwnerUserId: number?,
}

return {}
