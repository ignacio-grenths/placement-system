--!strict

const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const HeroLevelRules = require("../SystemPackage/HeroLevelRules")
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
	Splits a death's experience among the enemy heroes close enough to see
	it, with a bonus for sharing, so standing in lane is what levels a hero.
	A jungle monster is everyone's enemy, so its experience goes only to the
	killer's team.
]]
local function onUnitDied(unit: Unit, killer: Unit?)
	local xp = getXpReward(unit)
	if xp <= 0 then
		return
	end
	local rewardedTeam = if unit.Team == "Neutral" and killer then killer.Team else nil
	if unit.Team == "Neutral" and not rewardedTeam then
		return
	end

	local heroes = UnitServerService:FindInRadius(
		unit.Position,
		ProgressionCatalog.XpShareRadius,
		function(other)
			return other.Kind == "Hero"
				and other.Team ~= unit.Team
				and (rewardedTeam == nil or other.Team == rewardedTeam)
		end
	)
	local share = HeroLevelRules.getXpShare(xp, #heroes, ProgressionCatalog.XpShareBonus)
	for _, hero in heroes do
		HeroLevelServerService:GrantXp(hero, share)
	end
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
end

return Module
