--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const MinionWaveRules = require("./MinionWaveRules")

-- Seconds between minions of one wave, so the wave walks out in a line.
const SPAWN_SPACING = 0.6
-- Studs from a minion's center to an enemy's edge within which it notices
-- the enemy.
const AGGRO_RANGE = 14
-- Studs past AGGRO_RANGE that a minion chases before returning to its lane.
const CHASE_LEEWAY = 8
const WAYPOINT_REACHED_DISTANCE = 3

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type MinionRole = MinionWaveRules.MinionRole
type Team = UnitTypes.Team
type Unit = UnitTypes.Unit
type UnitStats = UnitTypes.UnitStats

-- Waypoints from the team's base to the enemy core.
export type Route = { Vector3 }

type MinionType = {
	TypeId: string,
	Stats: UnitStats,
}

type Lane = {
	Team: Team,
	Name: string,
	Route: Route,
}

local Module = {}

Module.MinionSpawned = Signal.new() :: Signal.Signal<Unit>

local minionTypes: { [MinionRole]: MinionType? } = {}
local lanes: { Lane } = {}
local superLaneKeys: { [string]: boolean? } = {}
local schedule: MinionWaveRules.Schedule = {
	FirstWaveTime = 60,
	Interval = 30,
}
local matchStartTime: number? = nil
local spawnedWaveCount = 0

local function getLaneKey(team: Team, laneName: string): string
	return `{team}:{laneName}`
end

local function isLaneEnemy(minion: Unit, other: Unit): boolean
	-- Aliens fight the other team, never the jungle's monsters.
	return other.Kind ~= "Monster" and UnitServerService:CanAttack(minion, other)
end

--[[
	Picks the nearest enemy alien or structure in range, and only falls back
	to a hero when there is none, so aliens keep pushing their lane.
]]
local function findTarget(minion: Unit): Unit?
	local nonHero = UnitServerService:FindNearest(minion.Position, AGGRO_RANGE, function(other)
		return other.Kind ~= "Hero" and isLaneEnemy(minion, other)
	end)
	if nonHero then
		return nonHero
	end

	return UnitServerService:FindNearest(minion.Position, AGGRO_RANGE, function(other)
		return other.Kind == "Hero" and isLaneEnemy(minion, other)
	end)
end

local function createBrain(route: Route): (Unit) -> ()
	local waypointIndex = math.min(2, #route)

	return function(minion: Unit)
		local order = minion.Order
		if order.Kind == "Attack" then
			local target = UnitServerService:GetUnit(order.TargetId)
			if
				target
				and isLaneEnemy(minion, target)
				and (target.Position - minion.Position).Magnitude - target.Stats.Radius
					<= AGGRO_RANGE + CHASE_LEEWAY
			then
				return
			end
		end

		local target = findTarget(minion)
		if target then
			UnitServerService:IssueOrder(minion, { Kind = "Attack", TargetId = target.Id })
			return
		end

		while
			waypointIndex < #route
			and (route[waypointIndex] - minion.Position).Magnitude <= WAYPOINT_REACHED_DISTANCE
		do
			waypointIndex += 1
		end
		-- A fight can carry a minion past its waypoint. Walking back to it
		-- would turn the wave around, so a passed waypoint is skipped.
		if waypointIndex < #route then
			local nextWaypoint = route[waypointIndex + 1]
			local distanceToNext = (nextWaypoint - minion.Position).Magnitude
			if distanceToNext < (nextWaypoint - route[waypointIndex]).Magnitude then
				waypointIndex += 1
			end
		end

		local destination = route[waypointIndex]
		if order.Kind ~= "Move" or order.Target ~= destination then
			UnitServerService:IssueOrder(minion, { Kind = "Move", Target = destination })
		end
	end
end

local function spawnMinion(lane: Lane, role: MinionRole)
	-- The match can end while a wave is still walking out.
	local minionType = minionTypes[role]
	if not matchStartTime or not minionType then
		return
	end

	local minion = UnitServerService:SpawnUnit({
		Kind = "Minion",
		TypeId = minionType.TypeId,
		Team = lane.Team,
		Stats = minionType.Stats,
		Position = lane.Route[1],
		Brain = createBrain(lane.Route),
	})
	Module.MinionSpawned:Fire(minion)
end

local function spawnWave(waveNumber: number)
	for _, lane in lanes do
		local isEnemyGateDown = superLaneKeys[getLaneKey(lane.Team, lane.Name)] == true
		for index, role in MinionWaveRules.getComposition(waveNumber, isEnemyGateDown) do
			SimClock.delay((index - 1) * SPAWN_SPACING, spawnMinion, lane, role :: MinionRole)
		end
	end
end

local function step()
	local startTime = matchStartTime
	if not startTime then
		return
	end

	local dueCount = MinionWaveRules.getWaveCount(schedule, SimClock.serverTime() - startTime)
	while spawnedWaveCount < dueCount do
		spawnedWaveCount += 1
		spawnWave(spawnedWaveCount)
	end
end

function Module:RegisterMinionType(role: MinionRole, typeId: string, stats: UnitStats)
	minionTypes[role] = {
		TypeId = typeId,
		Stats = stats,
	}
end

--[[
	Adds a lane a team sends waves down. The route runs from the team's base
	to the enemy core, and waves spawn at its first point.
]]
function Module:RegisterLane(team: Team, laneName: string, route: Route)
	assert(#route >= 2, "A lane route needs at least two points")
	table.insert(lanes, {
		Team = team,
		Name = laneName,
		Route = route,
	})
end

--[[
	Sets when waves leave, in seconds: the first after firstWaveTime on the
	match clock, then one every interval.
]]
function Module:SetSchedule(firstWaveTime: number, interval: number)
	assert(interval > 0, "The wave interval must be positive")
	schedule = {
		FirstWaveTime = firstWaveTime,
		Interval = interval,
	}
end

--[[
	Turns a super minion on or off at the front of the team's waves down a
	lane. It is on while the enemy gate in that lane is down.
]]
function Module:SetSuperLane(team: Team, laneName: string, isActive: boolean)
	superLaneKeys[getLaneKey(team, laneName)] = if isActive then true else nil
end

--[[
	Starts sending waves on a match clock that starts at a server time
	(SimClock.serverTime()).
]]
function Module:Begin(startTime: number)
	matchStartTime = startTime
	spawnedWaveCount = 0
end

function Module:Stop()
	matchStartTime = nil
end

function Module:Start()
	SimClock.onStep(step)
end

return Module
