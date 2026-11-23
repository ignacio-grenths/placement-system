--!strict

const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)

const ItemShopServerService = require("../SystemPackage/ItemShopServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function onHeroSpawned(hero: Unit)
	ItemShopServerService:OpenInventory(hero)
end

local function onHeroRemoved(hero: Unit)
	ItemShopServerService:CloseInventory(hero)
end

function Module:Init()
	HeroServerService.HeroSpawned:Connect(onHeroSpawned)
	HeroServerService.HeroRemoved:Connect(onHeroRemoved)
end

return Module
