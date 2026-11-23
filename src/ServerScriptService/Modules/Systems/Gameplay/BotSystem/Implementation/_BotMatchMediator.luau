--!strict

const RunService = game:GetService("RunService")

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
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type JungleCamp = BotServerService.JungleCamp
type JungleOptions = BotServerService.JungleOptions
type Objective = BotServerService.Objective
type Participant = MatchTypes.Participant
type Slot = AbilityTypes.Slot
type Unit = UnitTypes.Unit

-- A team's plan to take a river boss: its party gathers at the rally point,
-- then fights together.
type BossPlan = {
	BossKey: string,
	Rally: Vector3,
	IsFighting: boolean,
	-- os.clock() time the party stops waiting for stragglers.
	GatherDeadline: number,
}

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
-- Roles that leave their lane to take a river boss together; top and bot
-- lane hold their waves.
const BOSS_PARTY_ROLES = { Jungle = true, Mid = true, Support = true }
-- River bosses, the stronger first, with the party's average level each
-- needs before trying it.
const BOSSES = {
	{ Key = "HiveQueen", MinLevel = 11 },
	{ Key = "Skyray", MinLevel = 6 },
}
const MIN_PARTY_SIZE = 3
-- Below this many standing, the party gives up and goes back.
const MIN_FIGHTERS = 2
-- Share of max health every member needs to start a boss.
const READY_HEALTH_SHARE = 0.6
-- Studs short of the boss, toward home, where the party gathers.
const RALLY_DISTANCE = 30
-- Studs from the rally point that count as gathered.
const GATHER_RADIUS = 14
-- Seconds the party waits for stragglers before starting without them.
const GATHER_SECONDS = 25
-- Seconds between two looks at whether a team should go for a boss.
const PLAN_INTERVAL = 1

local Module = {}

-- Bot heroes in BOSS_PARTY_ROLES, by team.
local partyByTeam: { [string]: { Unit } } = {}
local plans: { [string]: BossPlan? } = {}
local planTimer = 0

local function getCampPosition(key: string): Vector3?
	for _, spot in MapLayout.Camps do
		if spot.Key == key then
			return spot.Position
		end
	end
	return nil
end

local function getStandingParty(team: string): { Unit }
	local standing = {}
	local party: { Unit } = partyByTeam[team] or {}
	for _, hero in party do
		if not hero.IsDead and not hero.IsRemoved then
			table.insert(standing, hero)
		end
	end
	return standing
end

local function isGathered(party: { Unit }, rally: Vector3): boolean
	for _, hero in party do
		if (hero.Position - rally).Magnitude > GATHER_RADIUS then
			return false
		end
	end
	return true
end

--[[
	Starts a boss plan when the whole party stands healthy and leveled
	enough, and drops it once the boss falls or too few fighters are left.
]]
local function updatePlan(team: MapLayout.MapTeam)
	local party = getStandingParty(team)
	local plan = plans[team]
	if plan then
		if #JungleServerService:GetCampMonsters(plan.BossKey) == 0 or #party < MIN_FIGHTERS then
			plans[team] = nil
		elseif not plan.IsFighting then
			plan.IsFighting = isGathered(party, plan.Rally) or os.clock() >= plan.GatherDeadline
		end
		return
	end

	if #party < MIN_PARTY_SIZE then
		return
	end
	local totalLevel = 0
	for _, hero in party do
		if hero.Health / math.max(hero.Stats.MaxHealth, 1) < READY_HEALTH_SHARE then
			return
		end
		totalLevel += HeroLevelServerService:GetLevel(hero)
	end
	local averageLevel = totalLevel / #party

	for _, boss in BOSSES do
		local position = getCampPosition(boss.Key)
		local isUp = #JungleServerService:GetCampMonsters(boss.Key) > 0
		if position and isUp and averageLevel >= boss.MinLevel then
			local home = MapLayout.Bases[team].Fountain
			plans[team] = {
				BossKey = boss.Key,
				Rally = position + (home - position).Unit * RALLY_DISTANCE,
				IsFighting = false,
				GatherDeadline = os.clock() + GATHER_SECONDS,
			}
			return
		end
	end
end

local function createObjective(team: string): () -> Objective?
	return function()
		local plan = plans[team]
		if not plan then
			return nil
		end
		if not plan.IsFighting then
			return { Point = plan.Rally }
		end

		-- The party focuses the weakest monster in the pit.
		local weakest: Unit? = nil
		for _, monster in JungleServerService:GetCampMonsters(plan.BossKey) do
			if monster.IsTargetable and (not weakest or monster.Health < weakest.Health) then
				weakest = monster
			end
		end
		if not weakest then
			return { Point = plan.Rally }
		end
		return { Point = weakest.Position, Target = weakest }
	end
end

local function onHeartbeat(frameTime: number)
	planTimer += frameTime
	if planTimer < PLAN_INTERVAL then
		return
	end
	planTimer = 0
	for team in MapLayout.Bases do
		updatePlan(team :: MapLayout.MapTeam)
	end
end

--[[
	A jungle bot clears the camps on its own side. The river bosses need a
	team, so it takes them only with its boss party.
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
	local isInBossParty = BOSS_PARTY_ROLES[participant.Role] == true
	local brain = BotServerService:CreateBrain({
		Lane = route,
		Fountain = base.Fountain,
		FountainRadius = base.FountainRadius,
		Jungle = if participant.Role == "Jungle"
			then createJungleOptions(team, participant.HeroId)
			else nil,
		GetObjective = if isInBossParty then createObjective(team) else nil,
	})
	local hero = HeroServerService:SpawnBotHero(participant.HeroId, participant.Team, brain)
	MatchServerService:AttachHero(participant, hero.Id)
	HeroLevelServerService:SetAutoRanking(hero, true)
	if isInBossParty then
		local party = partyByTeam[team] or {}
		table.insert(party, hero)
		partyByTeam[team] = party
	end
end

local function onParticipantRemoved(participant: Participant)
	local heroUnitId = participant.HeroUnitId
	if participant.Player or not heroUnitId then
		return
	end
	local hero = UnitServerService:GetUnit(heroUnitId)
	if hero then
		local party = partyByTeam[hero.Team]
		local index = if party then table.find(party, hero) else nil
		if party and index then
			table.remove(party, index)
		end
		HeroServerService:RemoveBotHero(hero)
	end
end

function Module:Init()
	MatchServerService.ParticipantAdded:Connect(onParticipantAdded)
	MatchServerService.ParticipantRemoved:Connect(onParticipantRemoved)
end

function Module:Start()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Module
