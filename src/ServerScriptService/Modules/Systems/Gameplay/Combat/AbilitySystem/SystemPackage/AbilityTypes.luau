--!strict

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

-- Q W E R are a hero's abilities, D and F its summoner spells, B its recall.
export type Slot = "Q" | "W" | "E" | "R" | "D" | "F" | "B"
export type ResourceKind = "Mana" | "Energy" | "Stamina" | "None"
-- Direction: fired along a line. Point: lands on a spot within range.
-- Unit: needs a target that passes TargetFilter. Self: no aim at all.
export type Targeting = "Direction" | "Point" | "Unit" | "Self"
-- EnemyUnit leaves out structures. AllyUnit means an allied tower, gate,
-- core, or alien.
export type TargetFilter = "EnemyUnit" | "EnemyHero" | "EnemyNonHero" | "AllyUnit"

-- What a client is told about an ability in its hero's loadout.
export type AbilityInfo = {
	Id: string,
	Name: string,
	Description: string,
	-- Seconds.
	Cooldown: number,
	Cost: number,
	Targeting: Targeting,
	-- Studs from the caster's edge.
	Range: number,
	TargetFilter: TargetFilter?,
}

-- Tuning numbers an ability's handler reads, such as Damage or Duration,
-- already picked for the rank it was cast at.
export type AbilityValues = { [string]: number }

-- Tuning numbers as a catalog lists them: one number for every rank, or a
-- list with one number per rank.
export type RankedValues = { [string]: number | { number } }

export type CastContext = {
	Caster: UnitTypes.Unit,
	Info: AbilityInfo,
	Values: AbilityValues,
	-- Within range of the caster, on the ground plane.
	AimPoint: Vector3,
	-- Flat and of length 1.
	Direction: Vector3,
	Target: UnitTypes.Unit?,
}

-- Returns false when the cast can't happen (Haru's swap with no clone out),
-- in which case nothing is spent and no cooldown starts.
export type AbilityHandler = (CastContext) -> boolean

export type ResourceProfile = {
	Kind: ResourceKind,
	-- Per second.
	RegenPerSecond: number,
	-- Seconds after spending before regeneration starts (stamina).
	RegenDelay: number,
	-- Restored when the hero's basic attack hits an enemy hero (stamina).
	RestoreOnHeroHit: number,
}

-- Where a client wants an ability aimed. TargetId is set for Unit abilities.
export type Aim = {
	Point: Vector3,
	TargetId: number?,
}

-- Visual-only effects the server asks every client to draw.
export type Effect =
	{
		Kind: "Projectile",
		Origin: Vector3,
		Direction: Vector3,
		Speed: number,
		Range: number,
		Width: number,
		Color: Color3,
	}
	| {
		Kind: "Ring",
		Position: Vector3,
		Radius: number,
		Color: Color3,
		Duration: number,
	}
	| {
		Kind: "Beam",
		From: Vector3,
		To: Vector3,
		Width: number,
		Color: Color3,
		Duration: number,
	}

return {}
