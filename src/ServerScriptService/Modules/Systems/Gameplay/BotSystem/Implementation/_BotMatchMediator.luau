--!strict

const HeroLevelServerService = require(
	"@game/ServerScriptService/Modules/Systems/Progression/HeroLevelSystem/SystemPackage/HeroLevelServerService"
)
const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const MatchServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchServerService"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const BotServerService = require("../SystemPackage/BotServerService")

const MatchTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchTypes"
)

type Participant = MatchTypes.Participant

-- The lane each role plays. The jungler shares mid until the jungle exists,
-- and the support follows its carry in bot lane.
const LANES_BY_ROLE: { [string]: MapLayout.LaneName } = {
	Top = "Top",
	Jungle = "Mid",
	Mid = "Mid",
	Bot = "Bot",
	Support = "Bot",
}

local Module = {}

local function onParticipantAdded(participant: Participant)
	if participant.Player then
		return
	end

	local team: MapLayout.MapTeam = participant.Team
	local route = MapLayout.Routes[team][LANES_BY_ROLE[participant.Role]]
	local base = MapLayout.Bases[team]
	local brain = BotServerService:CreateBrain({
		Lane = route,
		Fountain = base.Fountain,
		FountainRadius = base.FountainRadius,
	})
	local hero = HeroServerService:SpawnBotHero(participant.HeroId, participant.Team, brain)
	MatchServerService:AttachHero(participant, hero.Id)
	HeroLevelServerService:SetAutoRanking(hero, true)
end

local function onParticipantRemoved(participant: Participant)
	local heroUnitId = participant.HeroUnitId
	if participant.Player or not heroUnitId then
		return
	end
	local hero = UnitServerService:GetUnit(heroUnitId)
	if hero then
		HeroServerService:RemoveBotHero(hero)
	end
end

function Module:Init()
	MatchServerService.ParticipantAdded:Connect(onParticipantAdded)
	MatchServerService.ParticipantRemoved:Connect(onParticipantRemoved)
end

return Module
