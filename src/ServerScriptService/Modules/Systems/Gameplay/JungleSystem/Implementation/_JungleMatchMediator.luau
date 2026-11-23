--!strict

const MatchServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchServerService"
)

const JungleServerService = require("../SystemPackage/JungleServerService")

local Module = {}

local function onMatchStarted(startTime: number)
	JungleServerService:Begin(startTime)
end

local function onMatchEnded()
	JungleServerService:Stop()
end

function Module:Init()
	MatchServerService.MatchStarted:Connect(onMatchStarted)
	MatchServerService.MatchEnded:Connect(onMatchEnded)
end

return Module
