--!strict

const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)

const MatchServerService = require("../SystemPackage/MatchServerService")

const MatchTypes = require("../SystemPackage/MatchTypes")

type Participant = MatchTypes.Participant

local Module = {}

local function onParticipantAdded(participant: Participant)
	HeroServerService:SpawnHero(participant.Player, participant.HeroId, participant.Team)
end

local function onParticipantRemoved(participant: Participant)
	HeroServerService:RemoveHero(participant.Player)
end

function Module:Init()
	MatchServerService.ParticipantAdded:Connect(onParticipantAdded)
	MatchServerService.ParticipantRemoved:Connect(onParticipantRemoved)
end

return Module
