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
	if unit.Kind ~= "Hero" then
		return
	end
	-- Deaths to towers and aliens count as deaths but give no one a kill.
	local killerHeroId = if killer and killer.Kind == "Hero" then killer.Id else nil
	MatchServerService:RecordHeroDeath(unit.Id, killerHeroId)
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
end

return Module
