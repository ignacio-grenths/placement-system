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
	-- Jungle monsters. Nil colors would paint them in the neutral yellow, so
	-- each camp gets its own look. Tuned so a level 1 hero using only basic
	-- attacks clears a small camp losing about a third of its health, and a
	-- buff camp with Hunt losing about half.
	Glorp = {
		DisplayName = "Glorp",
		Stats = {
			MaxHealth = 200,
			Armor = 0,
			AttackDamage = 8,
			AttackRange = 2,
			AttackInterval = 1.2,
			MoveSpeed = 12,
			Radius = 1.2,
		},
		Visual = {
			Shape = "Ball",
			Size = Vector3.new(2.4, 2.4, 2.4),
			Color = Color3.fromRGB(120, 210, 90),
		},
	},
	Spitter = {
		DisplayName = "Spitter",
		Stats = {
			MaxHealth = 300,
			Armor = 5,
			AttackDamage = 12,
			AttackRange = 10,
			AttackInterval = 1.5,
			MoveSpeed = 12,
			Radius = 1.2,
			ProjectileSpeed = 40,
		},
		Visual = {
			Shape = "Ball",
			Size = Vector3.new(2.2, 2.2, 2.2),
			Color = Color3.fromRGB(190, 230, 70),
		},
	},
	Crawler = {
		DisplayName = "Crawler",
		Stats = {
			MaxHealth = 900,
			Armor = 15,
			AttackDamage = 25,
			AttackRange = 2.5,
			AttackInterval = 1.4,
			MoveSpeed = 12,
			Radius = 2,
		},
		Visual = {
			Shape = "Block",
			Size = Vector3.new(4, 2, 4),
			Color = Color3.fromRGB(140, 100, 70),
		},
	},
	RiftToad = {
		DisplayName = "Rift Toad",
		Stats = {
			MaxHealth = 1100,
			Armor = 15,
			AttackDamage = 28,
			AttackRange = 2.5,
			AttackInterval = 1.5,
			MoveSpeed = 12,
			Radius = 2.2,
		},
		Visual = {
			Shape = "Ball",
			Size = Vector3.new(4.4, 3.4, 4.4),
			Color = Color3.fromRGB(90, 160, 150),
		},
	},
	CrystalGolem = {
		DisplayName = "Crystal Golem",
		Stats = {
			MaxHealth = 1200,
			Armor = 10,
			AttackDamage = 25,
			AttackRange = 3,
			AttackInterval = 1.4,
			MoveSpeed = 12,
			Radius = 2.8,
		},
		Visual = {
			Shape = "Block",
			Size = Vector3.new(5, 6, 5),
			Color = Color3.fromRGB(110, 180, 255),
		},
	},
	EmberBeetle = {
		DisplayName = "Ember Beetle",
		Stats = {
			MaxHealth = 1200,
			Armor = 10,
			AttackDamage = 28,
			AttackRange = 3,
			AttackInterval = 1.4,
			MoveSpeed = 12,
			Radius = 2.8,
		},
		Visual = {
			Shape = "Ball",
			Size = Vector3.new(5.6, 4, 5.6),
			Color = Color3.fromRGB(255, 120, 50),
		},
	},
	Skyray = {
		DisplayName = "Skyray",
		Stats = {
			MaxHealth = 4000,
			Armor = 40,
			AttackDamage = 90,
			AttackRange = 12,
			AttackInterval = 1.6,
			MoveSpeed = 10,
			Radius = 4,
			ProjectileSpeed = 50,
		},
		Visual = {
			Shape = "Block",
			Size = Vector3.new(10, 3, 8),
			Color = Color3.fromRGB(120, 230, 255),
		},
	},
	HiveQueen = {
		DisplayName = "Hive Queen",
		Stats = {
			MaxHealth = 9000,
			Armor = 60,
			AttackDamage = 150,
			AttackRange = 4,
			AttackInterval = 1.8,
			MoveSpeed = 8,
			Radius = 6,
		},
		Visual = {
			Shape = "Ball",
			Size = Vector3.new(12, 10, 12),
			Color = Color3.fromRGB(170, 70, 200),
		},
	},
} :: { [string]: UnitEntry }

return Module
