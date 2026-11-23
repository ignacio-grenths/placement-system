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
	-- AbilityCatalog ids by slot (Q, W, E, R). Empty until the hero's kit is
	-- built.
	Abilities: { [string]: string },
	Stats: UnitStats,
	-- Placeholder body color until the hero's model exists.
	Color: Color3,
	SummonerSpells: { SummonerSpell },
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
		SummonerSpells = { "Blink", "Scorch" },
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
		SummonerSpells = { "Blink", "Mend" },
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
		Abilities = {},
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
		SummonerSpells = { "Blink", "Warp" },
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
		Abilities = {},
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
		SummonerSpells = { "Blink", "Hunt" },
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
		Abilities = {},
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
		SummonerSpells = { "Blink", "Drain" },
	},
} :: { [string]: HeroEntry }

return Module
