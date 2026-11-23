--!strict

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type UnitStats = UnitTypes.UnitStats

export type Role = "Top" | "Jungle" | "Mid" | "Bot" | "Support"
export type ResourceKind = "Mana" | "Energy" | "Stamina" | "None"
export type SummonerSpell = "Blink" | "Mend" | "Scorch" | "Hunt" | "Warp" | "Drain" | "Purify"

export type HeroEntry = {
	DisplayName: string,
	Title: string,
	Role: Role,
	Resource: ResourceKind,
	-- Zero for heroes on cooldowns only.
	MaxResource: number,
	-- Per second.
	ResourceRegen: number,
	-- Seconds after spending before the resource comes back (stamina).
	ResourceRegenDelay: number,
	-- Resource back per basic attack that hits an enemy hero (stamina).
	ResourceOnHeroHit: number,
	-- AbilityCatalog ids by slot (Q, W, E, R).
	Abilities: { [string]: string },
	-- Basic abilities to rank up first when ranks are chosen automatically.
	-- R always goes first when it can.
	SkillOrder: { string },
	Stats: UnitStats,
	-- Added to Stats on each level after the first, and to MaxResource for
	-- heroes whose pool grows (mana).
	Growth: {
		MaxHealth: number,
		Armor: number,
		AttackDamage: number,
		MaxResource: number,
	},
	-- The hero's signature color. Its look is in CharacterLookCatalog.
	Color: Color3,
	SummonerSpells: { SummonerSpell },
	-- ItemCatalog ids the shop marks as suggested for this hero, built
	-- around the pair that suits the role.
	SuggestedBuild: { string },
}

local Module = {}

-- Base stats share one band so no hero starts ahead: health 520 to 680,
-- attack 50 to 64. Each hero that gets more of one stat gives up another
-- (Ryuka has range but the lowest health, Brakk has armor but the lowest
-- attack). Tune heroes here, never in code.
Module.Heroes = {
	Haru = {
		DisplayName = "Haru",
		Title = "the Echo Ninja",
		Role = "Mid",
		Resource = "Energy",
		MaxResource = 200,
		ResourceRegen = 10,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Haru.Q", W = "Haru.W", E = "Haru.E", R = "Haru.R" },
		Stats = {
			MaxHealth = 580,
			Armor = 26,
			AttackDamage = 60,
			AttackRange = 2.5,
			AttackInterval = 1.45,
			MoveSpeed = 16.5,
			Radius = 1.3,
		},
		Color = Color3.fromRGB(255, 150, 40),
		SkillOrder = { "Q", "W", "E" },
		-- Energy is a fixed pool, so it does not grow.
		Growth = { MaxHealth = 82, Armor = 3, AttackDamage = 3.2, MaxResource = 0 },
		SummonerSpells = { "Blink", "Scorch" },
		SuggestedBuild = { "SwiftBoots", "KiConduit", "EchoBlade", "VoidShard" },
	},
	Ryuka = {
		DisplayName = "Ryuka",
		Title = "the Limit Breaker",
		Role = "Bot",
		Resource = "Mana",
		MaxResource = 320,
		ResourceRegen = 4,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Ryuka.Q", W = "Ryuka.W", E = "Ryuka.E", R = "Ryuka.R" },
		Stats = {
			MaxHealth = 520,
			Armor = 22,
			AttackDamage = 58,
			AttackRange = 17,
			AttackInterval = 1.55,
			MoveSpeed = 15.5,
			Radius = 1.3,
			ProjectileSpeed = 70,
		},
		Color = Color3.fromRGB(250, 220, 60),
		SkillOrder = { "Q", "W", "E" },
		Growth = { MaxHealth = 76, Armor = 3, AttackDamage = 3, MaxResource = 30 },
		SummonerSpells = { "Blink", "Mend" },
		SuggestedBuild = { "SwiftBoots", "BountyScope", "TrackersCloak", "EchoBlade" },
	},
	Torvik = {
		DisplayName = "Torvik",
		Title = "the Oathless",
		Role = "Top",
		Resource = "Stamina",
		MaxResource = 100,
		ResourceRegen = 25,
		ResourceRegenDelay = 2,
		ResourceOnHeroHit = 5,
		Abilities = { Q = "Torvik.Q", W = "Torvik.W", E = "Torvik.E", R = "Torvik.R" },
		Stats = {
			MaxHealth = 640,
			Armor = 30,
			AttackDamage = 64,
			AttackRange = 2.5,
			AttackInterval = 1.5,
			MoveSpeed = 16,
			Radius = 1.3,
		},
		Color = Color3.fromRGB(150, 110, 80),
		SkillOrder = { "Q", "E", "W" },
		-- Stamina is a fixed pool, so it does not grow.
		Growth = { MaxHealth = 90, Armor = 3.5, AttackDamage = 3.3, MaxResource = 0 },
		SummonerSpells = { "Blink", "Warp" },
		SuggestedBuild = { "SwiftBoots", "GrubHammer", "HullPlating", "BeetleCarapace" },
	},
	SeoDan = {
		DisplayName = "Seo Dan",
		Title = "the Shadow Sovereign",
		Role = "Jungle",
		Resource = "Mana",
		MaxResource = 300,
		ResourceRegen = 4,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "SeoDan.Q", W = "SeoDan.W", E = "SeoDan.E", R = "SeoDan.R" },
		Stats = {
			MaxHealth = 600,
			Armor = 28,
			AttackDamage = 58,
			AttackRange = 2.5,
			AttackInterval = 1.5,
			MoveSpeed = 16,
			Radius = 1.3,
		},
		Color = Color3.fromRGB(110, 80, 200),
		SkillOrder = { "Q", "W", "E" },
		Growth = { MaxHealth = 85, Armor = 3.2, AttackDamage = 3, MaxResource = 28 },
		SummonerSpells = { "Blink", "Hunt" },
		SuggestedBuild = { "SwiftBoots", "VoidShard", "KiConduit", "StarfallPendant" },
	},
	Brakk = {
		DisplayName = "Brakk",
		Title = "the Wallbreaker",
		Role = "Support",
		Resource = "None",
		MaxResource = 0,
		ResourceRegen = 0,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Brakk.Q", W = "Brakk.W", E = "Brakk.E", R = "Brakk.R" },
		Stats = {
			MaxHealth = 680,
			Armor = 34,
			AttackDamage = 50,
			AttackRange = 3,
			AttackInterval = 1.6,
			MoveSpeed = 15.5,
			Radius = 1.5,
		},
		Color = Color3.fromRGB(190, 70, 60),
		SkillOrder = { "W", "Q", "E" },
		Growth = { MaxHealth = 95, Armor = 4, AttackDamage = 2.5, MaxResource = 0 },
		SummonerSpells = { "Blink", "Drain" },
		SuggestedBuild = { "SwiftBoots", "TitanAegis", "MendersCharm", "StarfallPendant" },
	},
	-- The longest melee reach pays for itself with less health and attack
	-- than Torvik.
	Akane = {
		DisplayName = "Akane",
		Title = "the Crimson Lancer",
		Role = "Top",
		Resource = "Mana",
		MaxResource = 280,
		ResourceRegen = 4,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Akane.Q", W = "Akane.W", E = "Akane.E", R = "Akane.R" },
		Stats = {
			MaxHealth = 610,
			Armor = 28,
			AttackDamage = 60,
			AttackRange = 3.5,
			AttackInterval = 1.55,
			MoveSpeed = 16,
			Radius = 1.3,
		},
		Color = Color3.fromRGB(235, 60, 70),
		SkillOrder = { "Q", "W", "E" },
		Growth = { MaxHealth = 86, Armor = 3.3, AttackDamage = 3.1, MaxResource = 26 },
		SummonerSpells = { "Blink", "Warp" },
		SuggestedBuild = { "SwiftBoots", "GrubHammer", "HullPlating", "EchoBlade" },
	},
	-- The fastest attacks and feet among melee heroes, paid for with the
	-- least health and armor of them.
	Rin = {
		DisplayName = "Rin",
		Title = "the Storm Fox",
		Role = "Jungle",
		Resource = "Energy",
		MaxResource = 200,
		ResourceRegen = 10,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Rin.Q", W = "Rin.W", E = "Rin.E", R = "Rin.R" },
		Stats = {
			MaxHealth = 570,
			Armor = 25,
			AttackDamage = 58,
			AttackRange = 2.5,
			AttackInterval = 1.35,
			MoveSpeed = 16.5,
			Radius = 1.3,
		},
		Color = Color3.fromRGB(110, 200, 255),
		SkillOrder = { "Q", "E", "W" },
		-- Energy is a fixed pool, so it does not grow.
		Growth = { MaxHealth = 82, Armor = 3, AttackDamage = 3.1, MaxResource = 0 },
		SummonerSpells = { "Blink", "Hunt" },
		SuggestedBuild = { "SwiftBoots", "EchoBlade", "GrubHammer", "VoidShard" },
	},
	-- Range and control, paid for with the weakest attacks and frame.
	Yuki = {
		DisplayName = "Yuki",
		Title = "the Frost Witch",
		Role = "Mid",
		Resource = "Mana",
		MaxResource = 360,
		ResourceRegen = 4.5,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Yuki.Q", W = "Yuki.W", E = "Yuki.E", R = "Yuki.R" },
		Stats = {
			MaxHealth = 530,
			Armor = 21,
			AttackDamage = 52,
			AttackRange = 14,
			AttackInterval = 1.6,
			MoveSpeed = 15.5,
			Radius = 1.3,
			ProjectileSpeed = 60,
		},
		Color = Color3.fromRGB(150, 215, 255),
		SkillOrder = { "Q", "W", "E" },
		Growth = { MaxHealth = 78, Armor = 2.8, AttackDamage = 2.6, MaxResource = 32 },
		SummonerSpells = { "Blink", "Scorch" },
		SuggestedBuild = { "SwiftBoots", "KiConduit", "VoidShard", "StarfallPendant" },
	},
	-- Faster attacks than Ryuka for less reach.
	Kenji = {
		DisplayName = "Kenji",
		Title = "the Gunslinger",
		Role = "Bot",
		Resource = "Mana",
		MaxResource = 300,
		ResourceRegen = 4,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Kenji.Q", W = "Kenji.W", E = "Kenji.E", R = "Kenji.R" },
		Stats = {
			MaxHealth = 540,
			Armor = 22,
			AttackDamage = 60,
			AttackRange = 15,
			AttackInterval = 1.4,
			MoveSpeed = 15.5,
			Radius = 1.3,
			ProjectileSpeed = 90,
		},
		Color = Color3.fromRGB(90, 160, 110),
		SkillOrder = { "Q", "W", "E" },
		Growth = { MaxHealth = 78, Armor = 3, AttackDamage = 3.2, MaxResource = 28 },
		SummonerSpells = { "Blink", "Mend" },
		SuggestedBuild = { "SwiftBoots", "BountyScope", "TrackersCloak", "EchoBlade" },
	},
	-- Range and healing in place of Brakk's health and armor.
	Mio = {
		DisplayName = "Mio",
		Title = "the Shrine Maiden",
		Role = "Support",
		Resource = "Mana",
		MaxResource = 340,
		ResourceRegen = 5,
		ResourceRegenDelay = 0,
		ResourceOnHeroHit = 0,
		Abilities = { Q = "Mio.Q", W = "Mio.W", E = "Mio.E", R = "Mio.R" },
		Stats = {
			MaxHealth = 560,
			Armor = 24,
			AttackDamage = 50,
			AttackRange = 12,
			AttackInterval = 1.6,
			MoveSpeed = 15.5,
			Radius = 1.3,
			ProjectileSpeed = 55,
		},
		Color = Color3.fromRGB(220, 50, 60),
		SkillOrder = { "W", "Q", "E" },
		Growth = { MaxHealth = 82, Armor = 3.2, AttackDamage = 2.4, MaxResource = 30 },
		SummonerSpells = { "Blink", "Mend" },
		SuggestedBuild = { "SwiftBoots", "MendersCharm", "StarfallPendant", "KiConduit" },
	},
} :: { [string]: HeroEntry }

return Module
