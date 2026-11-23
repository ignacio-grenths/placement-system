--!strict

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const MatchNetwork = require("./MatchNetwork")

-- Seconds between the first player joining and the match clock starting, so
-- clients finish loading before the clock runs.
const START_DELAY = 5

const MatchTypes = require("./MatchTypes")

type Participant = MatchTypes.Participant
type Phase = MatchTypes.Phase
type ScoreEntry = MatchTypes.ScoreEntry
type Team = MatchTypes.Team

local Module = {}

Module.ParticipantAdded = Signal.new() :: Signal.Signal<Participant>
Module.ParticipantRemoved = Signal.new() :: Signal.Signal<Participant>
-- (server time the match clock starts)
Module.MatchStarted = Signal.new() :: Signal.Signal<number>
-- (winning team)
Module.MatchEnded = Signal.new() :: Signal.Signal<Team>

local participants: { [Player]: Participant? } = {}
local heroPool: { string } = {}
local phase: Phase = "Waiting"
local startTime = 0

local function setPhase(newPhase: Phase)
	phase = newPhase
	MatchNetwork.MatchState:SetAttribute("Phase", newPhase)
end

-- An attribute replicates to players who join later, which a remote would not.
local function publishScoreboard()
	local entries: { ScoreEntry } = {}
	for _, participant in participants do
		if participant then
			table.insert(entries, {
				UserId = participant.Player.UserId,
				Name = participant.Player.DisplayName,
				Team = participant.Team,
				HeroId = participant.HeroId,
				Kills = participant.Kills,
				Deaths = participant.Deaths,
			})
		end
	end
	MatchNetwork.MatchState:SetAttribute("Scoreboard", HttpService:JSONEncode(entries))
end

local function countTeam(team: Team): number
	local count = 0
	for _, participant in participants do
		if participant and participant.Team == team then
			count += 1
		end
	end
	return count
end

local function chooseTeam(): Team
	return if countTeam("Red") < countTeam("Blue") then "Red" else "Blue"
end

--[[
	Gives the first hero in the pool that nobody on the team plays yet. Once
	every hero is taken, teammates share the first one.
]]
local function chooseHero(team: Team): string
	local taken: { [string]: boolean? } = {}
	for _, participant in participants do
		if participant and participant.Team == team then
			taken[participant.HeroId] = true
		end
	end
	for _, heroId in heroPool do
		if not taken[heroId] then
			return heroId
		end
	end
	return heroPool[1]
end

local function startMatch()
	startTime = workspace:GetServerTimeNow() + START_DELAY
	MatchNetwork.MatchState:SetAttribute("StartTime", startTime)
	setPhase("Playing")
	Module.MatchStarted:Fire(startTime)
end

local function onPlayerAdded(player: Player)
	if phase == "Ended" or participants[player] then
		return
	end

	-- Annotated because luau-lsp widens a returned string literal to string.
	local team: Team = chooseTeam()
	local participant: Participant = {
		Player = player,
		Team = team,
		HeroId = chooseHero(team),
		Kills = 0,
		Deaths = 0,
	}
	participants[player] = participant
	publishScoreboard()
	Module.ParticipantAdded:Fire(participant)

	if phase == "Waiting" then
		startMatch()
	end
end

local function onPlayerRemoving(player: Player)
	local participant = participants[player]
	if not participant then
		return
	end
	participants[player] = nil
	publishScoreboard()
	Module.ParticipantRemoved:Fire(participant)
end

--[[
	Sets the heroes players are given, in the order they are handed out.
]]
function Module:SetHeroPool(heroIds: { string })
	assert(#heroIds > 0, "The hero pool needs at least one hero")
	heroPool = table.clone(heroIds)
end

function Module:GetPhase(): Phase
	return phase
end

--[[
	Returns seconds since the match clock started. Negative while it counts
	down to the start.
]]
function Module:GetElapsed(): number
	return workspace:GetServerTimeNow() - startTime
end

--[[
	Counts a hero death for the victim, and a kill for the killer when a
	player's hero landed the last hit.
]]
function Module:RecordHeroDeath(victim: Player, killer: Player?)
	local victimEntry = participants[victim]
	if victimEntry then
		victimEntry.Deaths += 1
	end
	local killerEntry = if killer then participants[killer] else nil
	if killerEntry and killer ~= victim then
		killerEntry.Kills += 1
	end
	publishScoreboard()
end

function Module:EndMatch(winner: Team)
	if phase ~= "Playing" then
		return
	end
	MatchNetwork.MatchState:SetAttribute("Winner", winner)
	setPhase("Ended")
	Module.MatchEnded:Fire(winner)
end

function Module:Init()
	MatchNetwork.MatchState:SetAttribute("StartTime", 0)
	MatchNetwork.MatchState:SetAttribute("Winner", "")
	setPhase("Waiting")
	publishScoreboard()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function Module:Start()
	-- Players who joined before Init connected are handled here, after every
	-- system's Init has connected to ParticipantAdded.
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Module
