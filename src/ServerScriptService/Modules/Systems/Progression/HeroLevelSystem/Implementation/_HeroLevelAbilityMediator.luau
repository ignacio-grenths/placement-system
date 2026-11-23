--!strict

const AbilityServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityServerService"
)

const HeroLevelServerService = require("../SystemPackage/HeroLevelServerService")

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

local Module = {}

local function onRankChanged(hero: UnitTypes.Unit, slot: string, rank: number)
	AbilityServerService:SetRank(hero, slot :: AbilityTypes.Slot, rank)
end

function Module:Init()
	HeroLevelServerService.RankChanged:Connect(onRankChanged)
end

return Module
