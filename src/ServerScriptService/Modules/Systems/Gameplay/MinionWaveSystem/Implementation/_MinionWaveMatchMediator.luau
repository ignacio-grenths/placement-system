--!strict

const MatchServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchServerService"
)

const MinionWaveServerService = require("../SystemPackage/MinionWaveServerService")

local Module = {}

local function onMatchStarted(startTime: number)
	MinionWaveServerService:Begin(startTime)
end

local function onMatchEnded()
	MinionWaveServerService:Stop()
end

function Module:Init()
	MatchServerService.MatchStarted:Connect(onMatchStarted)
	MatchServerService.MatchEnded:Connect(onMatchEnded)
end

return Module
