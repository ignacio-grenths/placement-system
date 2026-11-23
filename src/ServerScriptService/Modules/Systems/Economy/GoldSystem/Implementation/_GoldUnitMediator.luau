--!strict

const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const GoldServerService = require("../SystemPackage/GoldServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function payTeam(team: string, amount: number)
	for _, unit in UnitServerService:GetUnits() do
		local player = unit.OwnerPlayer
		if unit.Kind == "Hero" and unit.Team == team and not unit.IsRemoved and player then
			GoldServerService:AddGold(player, amount)
		end
	end
end

local function onUnitDied(unit: Unit, killer: Unit?)
	-- A fallen structure pays the whole team that took it, whoever landed the
	-- last hit, so pushing a lane together pays everyone.
	if unit.Kind == "Structure" then
		local winningTeam = if unit.Team == "Blue" then "Red" else "Blue"
		payTeam(winningTeam, ProgressionCatalog.StructureTeamGold)
		return
	end

	-- Everything else pays only the hero who landed the last hit.
	local player = if killer and killer.Kind == "Hero" then killer.OwnerPlayer else nil
	if not player then
		return
	end
	if unit.Kind == "Hero" then
		GoldServerService:AddGold(player, ProgressionCatalog.HeroKillGold)
	else
		local reward = ProgressionCatalog.UnitRewards[unit.TypeId]
		if reward then
			GoldServerService:AddGold(player, reward.Gold)
		end
	end
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
end

return Module
