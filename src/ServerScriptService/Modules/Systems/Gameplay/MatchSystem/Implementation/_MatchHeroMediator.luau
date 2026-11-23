--!strict

const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)

const MatchServerService = require("../SystemPackage/MatchServerService")

const MatchTypes = require("../SystemPackage/MatchTypes")

type Participant = MatchTypes.Participant

local Module = {}

-- Bots get their heroes from the bot system; this spawns players' heroes.
local function onParticipantAdded(participant: Participant)
	local player = participant.Player
	if player then
		local hero = HeroServerService:SpawnHero(player, participant.HeroId, participant.Team)
		MatchServerService:AttachHero(participant, hero.Id)
	end
end

local function onParticipantRemoved(participant: Participant)
	local player = participant.Player
	if player then
		HeroServerService:RemoveHero(player)
	end
end

function Module:Init()
	MatchServerService.ParticipantAdded:Connect(onParticipantAdded)
	MatchServerService.ParticipantRemoved:Connect(onParticipantRemoved)
end

return Module
