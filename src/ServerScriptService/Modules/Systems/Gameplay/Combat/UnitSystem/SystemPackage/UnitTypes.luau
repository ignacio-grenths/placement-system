--!strict

export type Team = "Blue" | "Red" | "Neutral"
export type UnitKind = "Hero" | "Minion" | "Monster" | "Structure"

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
	Stats: UnitStats,
	-- Always on the ground plane, so Y is zero.
	Position: Vector3,
	-- Radians around the vertical axis. Zero faces along -Z.
	Facing: number,
	Health: number,
	Resource: number,
	MaxResource: number,
	IsDead: boolean,
	IsRemoved: boolean,
	IsTargetable: boolean,
	RemoveOnDeath: boolean,
	OwnerPlayer: Player?,
	Order: Order,
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
