--!strict

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const MatchNetwork = require("./MatchNetwork")

-- Seconds between the first player joining and the match clock starting, so
-- clients finish loading before the clock runs.
const START_DELAY = 5
const TEAMS = { "Blue", "Red" }

const MatchTypes = require("./MatchTypes")

type Participant = MatchTypes.Participant
type Phase = MatchTypes.Phase
type Role = MatchTypes.Role
type ScoreEntry = MatchTypes.ScoreEntry
type Team = MatchTypes.Team

local Module = {}

-- Fires for players and bots alike. A bot has no Player.
Module.ParticipantAdded = Signal.new() :: Signal.Signal<Participant>
Module.ParticipantRemoved = Signal.new() :: Signal.Signal<Participant>
-- (server time the match clock starts)
Module.MatchStarted = Signal.new() :: Signal.Signal<number>
-- (winning team)
Module.MatchEnded = Signal.new() :: Signal.Signal<Team>

local participants: { Participant } = {}
local roles: { Role } = {}
local botHeroesByRole: { [string]: string? } = {}
local rolesByHero: { [string]: Role? } = {}
local heroPool: { string } = {}
local isFillingWithBots = false
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
		table.insert(entries, {
			UserId = if participant.Player then participant.Player.UserId else 0,
			Name = participant.Name,
			Team = participant.Team,
			HeroId = participant.HeroId,
			Kills = participant.Kills,
			Deaths = participant.Deaths,
		})
	end
	MatchNetwork.MatchState:SetAttribute("Scoreboard", HttpService:JSONEncode(entries))
end

local function findInRole(team: Team, role: Role): Participant?
	for _, participant in participants do
		if participant.Team == team and participant.Role == role then
			return participant
		end
	end
	return nil
end

local function findByPlayer(player: Player): Participant?
	for _, participant in participants do
		if participant.Player == player then
			return participant
		end
	end
	return nil
end

local function findByHeroUnit(heroUnitId: number): Participant?
	for _, participant in participants do
		if participant.HeroUnitId == heroUnitId then
			return participant
		end
	end
	return nil
end

local function countPlayers(team: Team): number
	local count = 0
	for _, participant in participants do
		if participant.Team == team and participant.Player then
			count += 1
		end
	end
	return count
end

local function chooseTeam(): Team
	return if countPlayers("Red") < countPlayers("Blue") then "Red" else "Blue"
end

local function isOpenForPlayer(team: Team, role: Role): boolean
	local occupant = findInRole(team, role)
	return occupant == nil or occupant.Player == nil
end

--[[
	Gives a joining player the first hero in the pool whose role no other
	player on the team holds. With the pool's roles all taken, the player
	gets any role still open, with that role's bot hero.
]]
local function chooseHeroAndRole(team: Team): (string, Role)
	for _, heroId in heroPool do
		-- Annotated because luau-lsp widens string literals read from a table.
		local role: Role? = rolesByHero[heroId]
		if role and isOpenForPlayer(team, role) then
			return heroId, role
		end
	end
	for _, openRole in roles do
		local role: Role = openRole :: Role
		if isOpenForPlayer(team, role) then
			return botHeroesByRole[role] or heroPool[1], role
		end
	end
	return heroPool[1], roles[1]
end

local function addParticipant(participant: Participant)
	table.insert(participants, participant)
	publishScoreboard()
	Module.ParticipantAdded:Fire(participant)
end

local function removeParticipant(participant: Participant)
	local index = table.find(participants, participant)
	if index then
		table.remove(participants, index)
		publishScoreboard()
		Module.ParticipantRemoved:Fire(participant)
	end
end

local function fillWithBots()
	if not isFillingWithBots or phase == "Ended" then
		return
	end
	for _, team in TEAMS do
		for _, slotRole in roles do
			local role: Role = slotRole :: Role
			local heroId = botHeroesByRole[role]
			if heroId and not findInRole(team :: Team, role) then
				addParticipant({
					Player = nil,
					-- The scoreboard shows the hero beside it, so "Bot" is enough.
					Name = "Bot",
					Team = team :: Team,
					Role = role,
					HeroId = heroId,
					HeroUnitId = nil,
					Kills = 0,
					Deaths = 0,
				})
			end
		end
	end
end

local function startMatch()
	startTime = workspace:GetServerTimeNow() + START_DELAY
	MatchNetwork.MatchState:SetAttribute("StartTime", startTime)
	setPhase("Playing")
	Module.MatchStarted:Fire(startTime)
end

local function onPlayerAdded(player: Player)
	if phase == "Ended" or findByPlayer(player) then
		return
	end

	-- Annotated because luau-lsp widens a returned string literal to string.
	local team: Team = chooseTeam()
	local heroId: string, role: Role = chooseHeroAndRole(team)
	-- A player always takes a bot's place, never the other way around.
	local bot = findInRole(team, role)
	if bot then
		removeParticipant(bot)
	end
	addParticipant({
		Player = player,
		Name = player.DisplayName,
		Team = team,
		Role = role,
		HeroId = heroId,
		HeroUnitId = nil,
		Kills = 0,
		Deaths = 0,
	})

	if phase == "Waiting" then
		startMatch()
	end
	fillWithBots()
end

local function onPlayerRemoving(player: Player)
	local participant = findByPlayer(player)
	if participant then
		removeParticipant(participant)
		-- A bot takes the empty slot, so the match never plays short.
		fillWithBots()
	end
end

--[[
	Sets the heroes players are given, in the order they are handed out.
]]
function Module:SetHeroPool(heroIds: { string })
	assert(#heroIds > 0, "The hero pool needs at least one hero")
	heroPool = table.clone(heroIds)
end

--[[
	Sets each team's role slots in order, and the hero a bot plays in each.
	Every hero's role is the one it fills as a bot.
]]
function Module:SetRoles(roleOrder: { Role }, botHeroes: { [string]: string })
	roles = table.clone(roleOrder)
	table.clear(botHeroesByRole)
	table.clear(rolesByHero)
	for role, heroId in botHeroes do
		botHeroesByRole[role] = heroId
		rolesByHero[heroId] = role :: Role
	end
end

--[[
	Turns on filling every slot no player holds with a bot once the match
	starts, and again whenever a player leaves.
]]
function Module:SetFillWithBots(isOn: boolean)
	isFillingWithBots = isOn
end

--[[
	Records which hero unit a participant plays, so its deaths and kills are
	counted for it.
]]
function Module:AttachHero(participant: Participant, heroUnitId: number)
	participant.HeroUnitId = heroUnitId
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
	Counts a hero death for its participant, and a kill for the participant
	whose hero landed the last hit.
]]
function Module:RecordHeroDeath(victimHeroId: number, killerHeroId: number?)
	local victim = findByHeroUnit(victimHeroId)
	if victim then
		victim.Deaths += 1
	end
	local killer = if killerHeroId then findByHeroUnit(killerHeroId) else nil
	if killer and killer ~= victim then
		killer.Kills += 1
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
