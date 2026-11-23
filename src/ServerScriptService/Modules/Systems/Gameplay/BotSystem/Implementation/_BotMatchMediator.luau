--!strict

const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")
const AbilityRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityRules"
)
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const HeroLevelServerService = require(
	"@game/ServerScriptService/Modules/Systems/Progression/HeroLevelSystem/SystemPackage/HeroLevelServerService"
)
const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)
const JungleServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/JungleSystem/SystemPackage/JungleServerService"
)
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const MatchServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchServerService"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const BotServerService = require("../SystemPackage/BotServerService")

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)
const MatchTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchTypes"
)

type JungleCamp = BotServerService.JungleCamp
type JungleOptions = BotServerService.JungleOptions
type Participant = MatchTypes.Participant
type Slot = AbilityTypes.Slot

-- The lane each role plays. The jungler helps mid while its camps are down,
-- and the support follows its carry in bot lane.
const LANES_BY_ROLE: { [string]: MapLayout.LaneName } = {
	Top = "Top",
	Jungle = "Mid",
	Mid = "Mid",
	Bot = "Bot",
	Support = "Bot",
}
-- A hero's summoner spells fill these slots in order.
const SPELL_SLOTS: { Slot } = { "D", "F" }
const FINISHER_SPELL = "Hunt"

local Module = {}

--[[
	A jungle bot clears the camps on its own side. The river bosses need a
	team, so it leaves them alone.
]]
local function createJungleOptions(team: MapLayout.MapTeam, heroId: string): JungleOptions
	local spots = {}
	for _, spot in MapLayout.Camps do
		if spot.Team == team then
			table.insert(spots, spot)
		end
	end

	local hero = HeroCatalog.Heroes[heroId]
	local spellIndex = if hero then table.find(hero.SummonerSpells, FINISHER_SPELL) else nil
	local finisher = AbilityCatalog.Abilities[`Spell.{FINISHER_SPELL}`]

	return {
		GetCamps = function(): { JungleCamp }
			local camps = table.create(#spots)
			for _, spot in spots do
				table.insert(camps, {
					Position = spot.Position,
					Monsters = JungleServerService:GetCampMonsters(spot.Key),
				})
			end
			return camps
		end,
		FinisherSlot = if spellIndex then SPELL_SLOTS[spellIndex] else nil,
		FinisherDamage = AbilityRules.resolveValues(finisher.Values, 1).Damage,
	}
end

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
		Jungle = if participant.Role == "Jungle"
			then createJungleOptions(team, participant.HeroId)
			else nil,
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
