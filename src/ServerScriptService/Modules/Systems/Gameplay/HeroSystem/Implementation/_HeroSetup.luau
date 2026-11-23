--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const HeroServerService = require("../SystemPackage/HeroServerService")

local Module = {}

function Module:Init()
	for heroId, hero in HeroCatalog.Heroes do
		HeroServerService:RegisterHero(heroId, {
			Stats = hero.Stats,
			MaxResource = hero.MaxResource,
		})
	end

	for team, base in MapLayout.Bases do
		HeroServerService:SetFountain(team :: MapLayout.MapTeam, base.Fountain, base.FountainRadius)
	end
end

return Module
