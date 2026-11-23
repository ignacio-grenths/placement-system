--!strict

const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)

const GoldServerService = require("../SystemPackage/GoldServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function onHeroSpawned(hero: Unit)
	GoldServerService:OpenAccount(hero)
end

local function onHeroRemoved(hero: Unit)
	GoldServerService:CloseAccount(hero)
end

function Module:Init()
	HeroServerService.HeroSpawned:Connect(onHeroSpawned)
	HeroServerService.HeroRemoved:Connect(onHeroRemoved)
end

return Module
