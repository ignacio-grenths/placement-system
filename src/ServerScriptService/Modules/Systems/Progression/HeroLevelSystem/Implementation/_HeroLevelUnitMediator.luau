--!strict

const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const HeroLevelServerService = require("../SystemPackage/HeroLevelServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function getXpReward(unit: Unit): number
	if unit.Kind == "Hero" then
		local level = HeroLevelServerService:GetLevel(unit)
		return ProgressionCatalog.HeroKillXp + ProgressionCatalog.HeroKillXpPerLevel * level
	end
	local reward = ProgressionCatalog.UnitRewards[unit.TypeId]
	return if reward then reward.Xp else 0
end

--[[
	Splits a death's experience evenly among the enemy heroes close enough to
	see it, so standing in lane is what levels a hero.
]]
local function onUnitDied(unit: Unit)
	local xp = getXpReward(unit)
	if xp <= 0 then
		return
	end

	local heroes = UnitServerService:FindInRadius(
		unit.Position,
		ProgressionCatalog.XpShareRadius,
		function(other)
			return other.Kind == "Hero" and other.Team ~= unit.Team
		end
	)
	for _, hero in heroes do
		HeroLevelServerService:GrantXp(hero, xp / #heroes)
	end
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
end

return Module
