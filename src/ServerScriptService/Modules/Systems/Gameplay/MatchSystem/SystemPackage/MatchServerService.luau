--!strict

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")

const MatchNetwork = require("./MatchNetwork")
const PickRules = require("./PickRules")

-- Seconds between the match starting and its clock running, so clients
-- finish loading and players find their heroes first.
const START_DELAY = 5
-- Seconds players have to pick a hero before the match starts without them.
const SELECT_SECONDS = 30
-- Most seconds the countdown waits for players to load, so one stuck client
-- can't hold the match.
const LOAD_WAIT_SECONDS = 20
const TEAMS = { "Blue", "Red" }
const REQUESTS_PER_SECOND = 10
-- A primary and a secondary position.
const MAX_PREFERRED_ROLES = 2

const MatchTypes = require("./MatchTypes")

type Participant = MatchTypes.Participant
type Phase = MatchTypes.Phase
type Pick = MatchTypes.Pick
type PoolHero = MatchTypes.PoolHero
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
-- Players choosing heroes, in join order. Empty outside the Selecting phase.
local picks: { Pick } = {}
local roles: { Role } = {}
local botHeroesByRole: { [string]: string? } = {}
local heroPool: { PoolHero } = {}
local isFillingWithBots = false
local isSpectating = false
local botHeroPicker: ((Team, Role) -> string)? = nil
local heroAccessCheck: ((Player, string) -> boolean)? = nil
local phase: Phase = "Waiting"
local startTime = 0
-- Bumped each time selection starts, so an earlier selection's timer can tell
-- it is stale.
local selectRound = 0
local isCountingDown = false
local loadedUserIds: { [number]: boolean? } = {}
local lastRequestTimes: { [Player]: number? } = {}

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

local function publishPicks()
	MatchNetwork.MatchState:SetAttribute("Picks", HttpService:JSONEncode(picks))
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

local function findPick(player: Player): Pick?
	for _, pick in picks do
		if pick.UserId == player.UserId then
			return pick
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
	for _, pick in picks do
		if pick.Team == team then
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
	Gives a player who joins mid-match the first hero in the pool whose role
	no other player on the team holds. With the pool's roles all taken, the
	player gets any role still open, with that role's bot hero.
]]
local function chooseHeroAndRole(team: Team): (string, Role)
	for _, hero in heroPool do
		if isOpenForPlayer(team, hero.Role) then
			return hero.HeroId, hero.Role
		end
	end
	for _, openRole in roles do
		local role: Role = openRole :: Role
		if isOpenForPlayer(team, role) then
			return botHeroesByRole[role] or heroPool[1].HeroId, role
		end
	end
	return heroPool[1].HeroId, roles[1]
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

local function addPlayer(player: Player, team: Team, heroId: string, role: Role)
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
end

local function fillWithBots()
	if not isFillingWithBots or phase == "Ended" then
		return
	end
	for _, team in TEAMS do
		for _, slotRole in roles do
			local role: Role = slotRole :: Role
			local heroId = if botHeroPicker
				then botHeroPicker(team :: Team, role)
				else botHeroesByRole[role]
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
	startTime = SimClock.serverTime() + START_DELAY
	MatchNetwork.MatchState:SetAttribute("StartTime", startTime)
	setPhase("Playing")
	Module.MatchStarted:Fire(startTime)
end

local function isEveryoneLockedIn(): boolean
	for _, pick in picks do
		if not pick.IsLockedIn then
			return false
		end
	end
	return #picks > 0
end

local function finishSelecting()
	local assignments = PickRules.resolve(picks, heroPool)
	for index, pick in picks do
		local player = Players:GetPlayerByUserId(pick.UserId)
		if player then
			local assignment = assignments[index]
			addPlayer(player, pick.Team, assignment.HeroId, assignment.Role)
		end
	end
	table.clear(picks)
	publishPicks()
	startMatch()
	fillWithBots()
end

local function onSelectTimeUp(round: number)
	if phase == "Selecting" and round == selectRound then
		finishSelecting()
	end
end

local function startCountdown(round: number)
	if phase ~= "Selecting" or round ~= selectRound or isCountingDown then
		return
	end
	isCountingDown = true
	MatchNetwork.MatchState:SetAttribute("SelectEndTime", SimClock.serverTime() + SELECT_SECONDS)
	SimClock.delay(SELECT_SECONDS, onSelectTimeUp, round)
end

local function startCountdownIfLoaded()
	if PickRules.isEveryoneLoaded(picks, loadedUserIds) then
		startCountdown(selectRound)
	end
end

local function startSelecting()
	selectRound += 1
	isCountingDown = false
	MatchNetwork.MatchState:SetAttribute("SelectEndTime", 0)
	setPhase("Selecting")
	SimClock.delay(LOAD_WAIT_SECONDS, startCountdown, selectRound)
	startCountdownIfLoaded()
end

local function onLoaded(player: Player)
	if loadedUserIds[player.UserId] then
		return
	end
	loadedUserIds[player.UserId] = true
	if phase == "Selecting" then
		startCountdownIfLoaded()
	end
end

local function canUseHero(player: Player, heroId: string): boolean
	return heroAccessCheck == nil or heroAccessCheck(player, heroId)
end

--[[
	The first hero the player may use in the first of their roles that has
	one open, or "" when none does.
]]
local function findPreferredHero(player: Player, pick: Pick, preferredRoles: { Role }): string
	for _, role in preferredRoles do
		for _, hero in heroPool do
			if
				hero.Role == role
				and canUseHero(player, hero.HeroId)
				and PickRules.isHeroOpen(picks, heroPool, pick, hero.HeroId)
			then
				return hero.HeroId
			end
		end
	end
	return ""
end

local function isRequestAllowed(player: Player): boolean
	-- Requests arrive in real time, whatever speed the simulation runs at.
	local now = os.clock()
	local last = lastRequestTimes[player]
	if last and now - last < 1 / REQUESTS_PER_SECOND then
		return false
	end
	lastRequestTimes[player] = now
	return true
end

local function onPickHero(player: Player, heroId: unknown)
	if phase ~= "Selecting" or typeof(heroId) ~= "string" or not isRequestAllowed(player) then
		return
	end
	local pick = findPick(player)
	if
		not pick
		or pick.IsLockedIn
		or pick.HeroId == heroId
		or not canUseHero(player, heroId)
		or not PickRules.isHeroOpen(picks, heroPool, pick, heroId)
	then
		return
	end
	pick.HeroId = heroId
	publishPicks()
end

local function onLockIn(player: Player)
	if phase ~= "Selecting" or not isRequestAllowed(player) then
		return
	end
	local pick = findPick(player)
	if
		not pick
		or pick.IsLockedIn
		or not canUseHero(player, pick.HeroId)
		or not PickRules.isHeroOpen(picks, heroPool, pick, pick.HeroId)
	then
		return
	end
	pick.IsLockedIn = true
	-- Teammates hovering a hero of the role just taken have to choose again.
	local role = PickRules.findRole(heroPool, pick.HeroId)
	for _, other in picks do
		if
			other ~= pick
			and other.Team == pick.Team
			and not other.IsLockedIn
			and PickRules.findRole(heroPool, other.HeroId) == role
		then
			other.HeroId = ""
		end
	end
	publishPicks()

	if isEveryoneLockedIn() then
		finishSelecting()
	end
end

local function joinMatch(player: Player, preferredRoles: { Role })
	if phase == "Ended" or findByPlayer(player) or findPick(player) then
		return
	end
	if isSpectating then
		if phase == "Waiting" then
			startMatch()
		end
		fillWithBots()
		return
	end

	-- Annotated because luau-lsp widens a returned string literal to string.
	local team: Team = chooseTeam()
	if phase == "Playing" then
		local heroId: string, role: Role = chooseHeroAndRole(team)
		addPlayer(player, team, heroId, role)
		fillWithBots()
		return
	end

	local pick: Pick = {
		UserId = player.UserId,
		Name = player.DisplayName,
		Team = team,
		HeroId = "",
		IsLockedIn = false,
	}
	pick.HeroId = findPreferredHero(player, pick, preferredRoles)
	table.insert(picks, pick)
	publishPicks()
	if phase == "Waiting" then
		startSelecting()
	end
end

-- Spectators never see the lobby, so they join on arrival. Everyone else
-- joins from the lobby's Find Match.
local function onPlayerAdded(player: Player)
	if isSpectating then
		joinMatch(player, {})
	end
end

local function onJoinMatch(player: Player, preferredRoles: unknown)
	if isSpectating or typeof(preferredRoles) ~= "table" or not isRequestAllowed(player) then
		return
	end
	local validRoles: { Role } = {}
	for index = 1, MAX_PREFERRED_ROLES do
		local role = (preferredRoles :: { unknown })[index]
		if typeof(role) == "string" and table.find(roles, role :: Role) then
			table.insert(validRoles, role :: Role)
		end
	end
	joinMatch(player, validRoles)
end

local function onPlayerRemoving(player: Player)
	lastRequestTimes[player] = nil
	loadedUserIds[player.UserId] = nil

	local pick = findPick(player)
	if pick then
		table.remove(picks, table.find(picks, pick) :: number)
		publishPicks()
		if #picks == 0 then
			setPhase("Waiting")
		elseif isEveryoneLockedIn() then
			finishSelecting()
		else
			startCountdownIfLoaded()
		end
		return
	end

	local participant = findByPlayer(player)
	if participant then
		removeParticipant(participant)
		-- A bot takes the empty slot, so the match never plays short.
		fillWithBots()
	end
end

--[[
	Sets the heroes players may pick, each with the role it plays, in the
	order they are handed to players who pick none.
]]
function Module:SetHeroPool(heroes: { PoolHero })
	assert(#heroes > 0, "The hero pool needs at least one hero")
	heroPool = table.clone(heroes)
	MatchNetwork.MatchState:SetAttribute("HeroPool", HttpService:JSONEncode(heroPool))
end

--[[
	Sets each team's role slots in order, and the hero a bot plays in each.
]]
function Module:SetRoles(roleOrder: { Role }, botHeroes: { [string]: string })
	roles = table.clone(roleOrder)
	table.clear(botHeroesByRole)
	for role, heroId in botHeroes do
		botHeroesByRole[role] = heroId
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
	Turns on watching: players who join take no slot, get no hero, and skip
	hero selection, so every slot plays as a bot. Call it before players
	join.
]]
function Module:SetPlayersSpectate(isOn: boolean)
	isSpectating = isOn
	MatchNetwork.MatchState:SetAttribute("PlayersSpectate", isOn)
end

--[[
	Starts an all-bot match without waiting for a player to join, so a match
	can run in Studio's Run mode with nobody connected. Needs
	SetPlayersSpectate on, and does nothing once a match has started.
]]
function Module:StartBotMatch()
	assert(isSpectating, "An all-bot match needs players to spectate")
	if phase ~= "Waiting" then
		return
	end
	startMatch()
	fillWithBots()
end

--[[
	Sets which heroes a player may pick. Nil lets everyone pick any hero.
]]
function Module:SetHeroAccessCheck(check: ((player: Player, heroId: string) -> boolean)?)
	heroAccessCheck = check
end

--[[
	Sets who chooses each bot's hero, by team and role. Nil goes back to the
	hero set for the role in SetRoles.
]]
function Module:SetBotHeroPicker(pick: ((team: Team, role: Role) -> string)?)
	botHeroPicker = pick
end

--[[
	Returns the match's slots, players and bots alike. Read it; never change
	it.
]]
function Module:GetParticipants(): { Participant }
	return participants
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
	return SimClock.serverTime() - startTime
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
	MatchNetwork.MatchState:SetAttribute("SelectEndTime", 0)
	MatchNetwork.MatchState:SetAttribute("Winner", "")
	setPhase("Waiting")
	publishScoreboard()
	publishPicks()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	MatchNetwork.PickHero.OnServerEvent:Connect(onPickHero)
	MatchNetwork.LockIn.OnServerEvent:Connect(onLockIn)
	MatchNetwork.Loaded.OnServerEvent:Connect(onLoaded)
	MatchNetwork.JoinMatch.OnServerEvent:Connect(onJoinMatch)
end

function Module:Start()
	-- Players who joined before Init connected are handled here, after every
	-- system's Init has connected to ParticipantAdded.
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Module
