--!strict

export type CampEntry = {
	-- UnitCatalog ids of the monsters in the camp.
	Monsters: { string },
	-- Seconds on the match clock before the camp first appears.
	FirstSpawn: number,
	-- Seconds after the camp is cleared before it comes back.
	Respawn: number,
}

export type BuffInfo = {
	Name: string,
	-- One short line on what the buff does, for the HUD.
	Description: string,
	Color: Color3,
}

local Module = {}

-- By MapLayout camp Id, which Blue's and Red's copies of a camp share.
Module.Camps = {
	WestSmallNorth = { Monsters = { "Glorp", "Glorp", "Glorp" }, FirstSpawn = 60, Respawn = 120 },
	WestSmallSouth = { Monsters = { "Spitter", "Spitter" }, FirstSpawn = 60, Respawn = 120 },
	SouthSmallWest = { Monsters = { "Crawler" }, FirstSpawn = 60, Respawn = 120 },
	SouthSmallEast = { Monsters = { "RiftToad" }, FirstSpawn = 60, Respawn = 120 },
	CrystalGolem = { Monsters = { "CrystalGolem" }, FirstSpawn = 60, Respawn = 300 },
	EmberBeetle = { Monsters = { "EmberBeetle" }, FirstSpawn = 60, Respawn = 300 },
	Skyray = { Monsters = { "Skyray" }, FirstSpawn = 300, Respawn = 300 },
	HiveQueen = { Monsters = { "HiveQueen" }, FirstSpawn = 840, Respawn = 360 },
} :: { [string]: CampEntry }

-- Focus, from the Crystal Golem: cooldowns run faster for Duration seconds.
Module.Focus = {
	Duration = 90,
	AbilityHaste = 20,
}

-- Burn, from the Ember Beetle: for Duration seconds, the holder's basic
-- attacks slow what they hit and burn it for BurnSeconds.
Module.Burn = {
	Duration = 90,
	SlowMultiplier = 0.8,
	SlowSeconds = 1.5,
	DamagePerSecond = 8,
	BurnSeconds = 3,
}

-- Each Skyray kill adds this much to every hero on the killing team, for the
-- rest of the match.
Module.Skyray = {
	AttackDamage = 6,
	AbilityPower = 6,
}

-- Hive Call, from the Hive Queen: the killing team's aliens hit harder and
-- take less damage for Duration seconds.
Module.HiveCall = {
	Duration = 180,
	AttackDamageMultiplier = 1.5,
	Armor = 40,
}

-- How each buff shows on the HUD, by buff id.
Module.BuffInfo = {
	Focus = {
		Name = "Focus",
		Description = "Faster cooldowns",
		Color = Color3.fromRGB(110, 180, 255),
	},
	Burn = {
		Name = "Burn",
		Description = "Attacks slow and burn",
		Color = Color3.fromRGB(255, 130, 60),
	},
	Skyray = {
		Name = "Skyray",
		Description = "More attack and power",
		Color = Color3.fromRGB(120, 230, 255),
	},
	HiveCall = {
		Name = "Hive Call",
		Description = "Your aliens are stronger",
		Color = Color3.fromRGB(190, 90, 230),
	},
} :: { [string]: BuffInfo? }

-- Studs from its camp that a monster chases before it gives up and goes home.
Module.LeashRadius = 22
-- Studs between the monsters of one camp.
Module.MonsterSpacing = 3

return Module
