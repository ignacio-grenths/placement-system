--!strict

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const MatchServerService = require("../SystemPackage/MatchServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function onUnitDied(unit: Unit, killer: Unit?)
	local victim = unit.OwnerPlayer
	if unit.Kind ~= "Hero" or not victim then
		return
	end
	-- Deaths to towers and aliens count as deaths but give no one a kill.
	local killerPlayer = if killer and killer.Kind == "Hero" then killer.OwnerPlayer else nil
	MatchServerService:RecordHeroDeath(victim, killerPlayer)
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
end

return Module
