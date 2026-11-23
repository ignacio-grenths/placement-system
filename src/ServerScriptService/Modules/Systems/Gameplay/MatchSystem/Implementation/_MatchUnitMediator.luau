--!strict

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const MatchServerService = require("../SystemPackage/MatchServerService")

local Module = {}

local function onMatchEnded()
	-- Everything freezes where it stands once a core falls.
	UnitServerService:SetPaused(true)
end

function Module:Init()
	MatchServerService.MatchEnded:Connect(onMatchEnded)
end

return Module
