--!strict

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type UnitStats = UnitTypes.UnitStats

export type VisualShape = "Ball" | "Block" | "Cylinder"

export type UnitEntry = {
	DisplayName: string,
	Stats: UnitStats,
	Visual: {
		Shape: VisualShape,
		-- Width, height, and depth in studs.
		Size: Vector3,
		-- Nil paints the unit in its team's color.
		Color: Color3?,
	},
}

local Module = {}

-- Placeholder art until real models arrive: every shape and size here stands
-- in for a model.
Module.Units = {
	Zib = {
		DisplayName = "Zib",
		Stats = {
			MaxHealth = 450,
			Armor = 0,
			AttackDamage = 12,
			AttackRange = 2,
			AttackInterval = 0.8,
			MoveSpeed = 11,
			Radius = 1.2,
		},
		Visual = { Shape = "Ball", Size = Vector3.new(2.4, 2.4, 2.4) },
	},
	Blip = {
		DisplayName = "Blip",
		Stats = {
			MaxHealth = 290,
			Armor = 0,
			AttackDamage = 22,
			AttackRange = 14,
			AttackInterval = 1.6,
			MoveSpeed = 11,
			Radius = 1,
			ProjectileSpeed = 50,
		},
		Visual = { Shape = "Ball", Size = Vector3.new(2, 2, 2) },
	},
	GrubTank = {
		DisplayName = "Grub Tank",
		Stats = {
			MaxHealth = 900,
			Armor = 10,
			AttackDamage = 40,
			AttackRange = 20,
			AttackInterval = 2,
			MoveSpeed = 11,
			Radius = 1.8,
			ProjectileSpeed = 45,
		},
		Visual = { Shape = "Block", Size = Vector3.new(3.6, 2.6, 4.4) },
	},
	MegaZib = {
		DisplayName = "Mega Zib",
		Stats = {
			MaxHealth = 1600,
			Armor = 30,
			AttackDamage = 60,
			AttackRange = 2.5,
			AttackInterval = 0.9,
			MoveSpeed = 11,
			Radius = 2,
		},
		Visual = { Shape = "Ball", Size = Vector3.new(4, 4, 4) },
	},
	OuterTower = {
		DisplayName = "Outer Tower",
		Stats = {
			MaxHealth = 3000,
			Armor = 40,
			AttackDamage = 150,
			AttackRange = 20,
			AttackInterval = 0.9,
			MoveSpeed = 0,
			Radius = 4,
			ProjectileSpeed = 80,
		},
		Visual = { Shape = "Cylinder", Size = Vector3.new(8, 14, 8) },
	},
	InnerTower = {
		DisplayName = "Inner Tower",
		Stats = {
			MaxHealth = 3500,
			Armor = 45,
			AttackDamage = 170,
			AttackRange = 20,
			AttackInterval = 0.9,
			MoveSpeed = 0,
			Radius = 4,
			ProjectileSpeed = 80,
		},
		Visual = { Shape = "Cylinder", Size = Vector3.new(8, 16, 8) },
	},
	Gate = {
		DisplayName = "Base Gate",
		Stats = {
			MaxHealth = 2500,
			Armor = 40,
			AttackDamage = 0,
			AttackRange = 0,
			AttackInterval = 1,
			MoveSpeed = 0,
			Radius = 5,
		},
		Visual = { Shape = "Block", Size = Vector3.new(10, 8, 10) },
	},
	Core = {
		DisplayName = "Core",
		Stats = {
			MaxHealth = 4000,
			Armor = 40,
			AttackDamage = 0,
			AttackRange = 0,
			AttackInterval = 1,
			MoveSpeed = 0,
			Radius = 7,
		},
		Visual = { Shape = "Ball", Size = Vector3.new(14, 14, 14) },
	},
} :: { [string]: UnitEntry }

return Module
