--!strict

export type SkinEntry = {
	HeroId: string,
	Name: string,
	Robux: number,
	-- The developer product that sells it. Nil until the product exists.
	ProductId: number?,
	-- Swatch colors the store shows, main color first.
	Colors: { Color3 },
}

local Module = {}

-- Coins a player has before any match pays out.
Module.StarterCoins = 3000

-- Free from the start: the easiest hero of each role.
Module.FreeHeroes = { "Akane", "Rin", "Yuki", "Ryuka", "Brakk" }

-- Every paid hero costs the same, since every hero has the same power budget.
Module.HeroCoinPrice = 3000
Module.HeroRobuxPrice = 199

-- Developer products that unlock a hero at once, by hero id. A hero missing
-- here can't be bought with Robux yet.
Module.HeroProductIds = {} :: { [string]: number? }

-- By skin id. Skin ids share one namespace with hero ids, so none may match a
-- hero id.
Module.Skins = {
	AkaneBlossom = {
		HeroId = "Akane",
		Name = "Blossom Festival Akane",
		Robux = 149,
		ProductId = nil,
		Colors = { Color3.fromRGB(245, 170, 200), Color3.fromRGB(255, 240, 245) },
	},
	RinAutumn = {
		HeroId = "Rin",
		Name = "Autumn Spirit Rin",
		Robux = 99,
		ProductId = nil,
		Colors = { Color3.fromRGB(215, 110, 40), Color3.fromRGB(250, 210, 120) },
	},
	YukiAurora = {
		HeroId = "Yuki",
		Name = "Midnight Aurora Yuki",
		Robux = 149,
		ProductId = nil,
		Colors = { Color3.fromRGB(40, 50, 120), Color3.fromRGB(120, 240, 200) },
	},
	RyukaEmber = {
		HeroId = "Ryuka",
		Name = "Ember Huntress Ryuka",
		Robux = 99,
		ProductId = nil,
		Colors = { Color3.fromRGB(160, 30, 30), Color3.fromRGB(255, 170, 60) },
	},
	BrakkGolden = {
		HeroId = "Brakk",
		Name = "Golden Bulwark Brakk",
		Robux = 149,
		ProductId = nil,
		Colors = { Color3.fromRGB(220, 175, 60), Color3.fromRGB(90, 60, 30) },
	},
	HaruMoonlit = {
		HeroId = "Haru",
		Name = "Moonlit Shadow Haru",
		Robux = 99,
		ProductId = nil,
		Colors = { Color3.fromRGB(70, 70, 110), Color3.fromRGB(210, 220, 255) },
	},
} :: { [string]: SkinEntry }

return Module
