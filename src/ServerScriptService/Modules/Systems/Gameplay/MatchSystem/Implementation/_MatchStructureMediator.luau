--!strict

const StructureServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/StructureSystem/SystemPackage/StructureServerService"
)

const MatchServerService = require("../SystemPackage/MatchServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

local Module = {}

local function onCoreDestroyed(losingTeam: UnitTypes.Team)
	if losingTeam == "Blue" then
		MatchServerService:EndMatch("Red")
	elseif losingTeam == "Red" then
		MatchServerService:EndMatch("Blue")
	end
end

function Module:Init()
	StructureServerService.CoreDestroyed:Connect(onCoreDestroyed)
end

return Module
