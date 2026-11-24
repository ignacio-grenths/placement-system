--!strict

const HttpService = game:GetService("HttpService")

const ModuleLoader = require("@game/ReplicatedStorage/Packages/ModuleLoader")

const HeroLevelServerService = require(
	"@game/ServerScriptService/Modules/Systems/Progression/HeroLevelSystem/SystemPackage/HeroLevelServerService"
)
const JungleServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/JungleSystem/SystemPackage/JungleServerService"
)
const MatchServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchServerService"
)
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const BalanceReport = require("../SystemPackage/BalanceReport")

-- A balance run starts when the place has this Workspace attribute: the
-- simulation steps per frame, so 8 plays a match eight times as fast.
const SPEED_ATTRIBUTE = "BalanceRunSpeed"
-- Every report printed to the output starts with this, to find them later.
const LOG_PREFIX = "[BalanceRun]"
-- A match still going after this many minutes ends the run without a winner.
const TIMEOUT_MINUTES = 45
const BOSS_KINDS: { [string]: boolean? } = { HiveQueen = true, Skyray = true }

const MatchTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchTypes"
)
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type DamageKind = UnitTypes.DamageKind
type Team = MatchTypes.Team
type Unit = UnitTypes.Unit

local Module = {}

-- By hero unit id: damage dealt to enemy heroes.
local heroDamage: { [number]: number } = {}
local structures: { [string]: number } = { Blue = 0, Red = 0 }
local bosses: { [string]: number } = { Blue = 0, Red = 0 }
local matchStartTime = 0
local isReported = false
local isBalanceRun = false

local function getOtherTeam(team: string): string
	return if team == "Blue" then "Red" else "Blue"
end

local function onUnitDamaged(target: Unit, source: Unit?, dealt: number, _kind: DamageKind)
	if
		source
		and source.Kind == "Hero"
		and target.Kind == "Hero"
		and source.Team ~= target.Team
	then
		heroDamage[source.Id] = (heroDamage[source.Id] or 0) + dealt
	end
end

local function onUnitDied(unit: Unit)
	if unit.Kind == "Structure" then
		local destroyer = getOtherTeam(unit.Team)
		structures[destroyer] += 1
	end
end

local function onCampCleared(_key: string, kind: string, killer: Unit?)
	if BOSS_KINDS[kind] and killer and bosses[killer.Team] then
		bosses[killer.Team] += 1
	end
end

local function report(winner: string)
	if isReported then
		return
	end
	isReported = true

	local heroes: { BalanceReport.HeroLine } = {}
	for _, participant in MatchServerService:GetParticipants() do
		local unitId = participant.HeroUnitId
		local hero = if unitId then UnitServerService:GetUnit(unitId) else nil
		local heroLine: BalanceReport.HeroLine = {
			Team = participant.Team :: string,
			Role = participant.Role :: string,
			Hero = participant.HeroId,
			Kills = participant.Kills,
			Deaths = participant.Deaths,
			Level = if hero then HeroLevelServerService:GetLevel(hero) else 0,
			HeroDamage = math.round(if unitId then heroDamage[unitId] or 0 else 0),
		}
		table.insert(heroes, heroLine)
	end

	local matchReport: BalanceReport.MatchReport = {
		Winner = winner,
		Minutes = math.round((SimClock.serverTime() - matchStartTime) / 60 * 10) / 10,
		Heroes = heroes,
		Structures = structures,
		Bosses = bosses,
	}
	print(`{LOG_PREFIX} {HttpService:JSONEncode(matchReport)}`)
end

local function onMatchStarted(startTime: number)
	matchStartTime = startTime
	local timeout = startTime - SimClock.serverTime() + TIMEOUT_MINUTES * 60
	SimClock.delay(timeout, report, "None")
end

local function onMatchEnded(winner: Team)
	report(winner)
end

function Module:Init()
	local speed = workspace:GetAttribute(SPEED_ATTRIBUTE)
	if typeof(speed) ~= "number" or speed < 1 then
		return
	end

	isBalanceRun = true
	SimClock.setSpeed(math.floor(speed))
	MatchServerService:SetPlayersSpectate(true)
	MatchServerService.MatchStarted:Connect(onMatchStarted)
	MatchServerService.MatchEnded:Connect(onMatchEnded)
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitDied:Connect(onUnitDied)
	JungleServerService.CampCleared:Connect(onCampCleared)
end

function Module:Start()
	if not isBalanceRun then
		return
	end
	-- Run mode has no player to start the match. Other systems build the map
	-- and units in their own Start, so the match waits for all of them.
	task.spawn(function()
		while not ModuleLoader.IsServerLoaded() do
			task.wait()
		end
		MatchServerService:StartBotMatch()
	end)
end

return Module
