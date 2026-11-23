--!strict

const MatchServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchServerService"
)
const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")

const GoldServerService = require("../SystemPackage/GoldServerService")

local Module = {}

local function onMatchStarted(startTime: number)
	GoldServerService:StartPassiveIncome(
		ProgressionCatalog.PassiveGoldPerSecond,
		startTime + ProgressionCatalog.PassiveGoldStart
	)
end

local function onMatchEnded()
	GoldServerService:StopPassiveIncome()
end

function Module:Init()
	MatchServerService.MatchStarted:Connect(onMatchStarted)
	MatchServerService.MatchEnded:Connect(onMatchEnded)
end

return Module
