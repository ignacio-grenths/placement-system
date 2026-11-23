--!strict

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const CombatRules = require("./CombatRules")
const Navigation = require("./Navigation")
const UnitNetwork = require("./UnitNetwork")
const UnitSnapshotCodec = require("./UnitSnapshotCodec")

-- Snapshots are unreliable and can drop, so every unit is resent at least
-- this often (seconds) even when nothing about it changed.
const REFRESH_INTERVAL = 1
const THINK_INTERVAL = 0.2
-- A long frame would let units step through each other and past targets.
const MAX_STEP = 0.1
const SEPARATION_INTERVAL = 0.05
-- Must be at least the largest pair of radii that can touch, or units in
-- neighboring cells overlap without noticing each other.
const SEPARATION_CELL_SIZE = 10
const SEPARATION_CELL_OFFSET = 10000
const PROJECTILE_HIT_DISTANCE = 1
-- Studs inside its reach a chasing unit stops. Vector3 holds 32-bit floats,
-- so a unit stopped exactly at its reach can measure a hair outside it
-- forever and never attack a target that stands still.
const CHASE_SLACK = 0.1
-- Seconds a path around walls is trusted before it is found again.
const REPATH_INTERVAL = 0.5
-- Studs a path's goal may drift, as when chasing, before it is found again.
const REPATH_DISTANCE = 4
-- Studs from a waypoint at which a walker moves on to the next.
const WAYPOINT_REACHED_DISTANCE = 1
const SYNC_COOLDOWN = 5
-- Unit ids travel as unsigned 16-bit values.
const MAX_UNIT_ID = 65535
-- Share of healing a unit still receives while its healing is cut.
const HEALING_CUT_SHARE = 0.6
const MOVE_EPOCH_COUNT = 256

const UnitTypes = require("./UnitTypes")

type DamageKind = UnitTypes.DamageKind
type Order = UnitTypes.Order
type StatModifier = UnitTypes.StatModifier
type Team = UnitTypes.Team
type Unit = UnitTypes.Unit
type UnitInfo = UnitTypes.UnitInfo
type UnitKind = UnitTypes.UnitKind
type UnitStats = UnitTypes.UnitStats

export type SpawnOptions = {
	Kind: UnitKind,
	TypeId: string,
	Team: Team,
	Stats: UnitStats,
	Position: Vector3,
	OwnerPlayer: Player?,
	-- Runs a few times a second to choose the unit's orders.
	Brain: ((Unit) -> ())?,
	MaxResource: number?,
	IsTargetable: boolean?,
	-- Defaults to true. Heroes stay so they can be revived.
	RemoveOnDeath: boolean?,
}

export type RootOptions = {
	-- A root the unit puts on itself, like a channel, ignores its immunity.
	IsSelfApplied: boolean?,
}

-- Who sees what, for fog of war. A team always sees its own units.
export type Visibility = {
	IsUnitVisible: (unit: Unit, team: Team) -> boolean,
	IsPointVisible: (position: Vector3, team: Team) -> boolean,
	-- The team whose sight a player shares, or nil for a player who sees
	-- everything, such as a spectator.
	GetViewerTeam: (player: Player) -> Team?,
}

type Projectile = {
	SourceId: number,
	TargetId: number,
	Position: Vector3,
	Speed: number,
	Damage: number,
}

type SentState = {
	X: number,
	Z: number,
	Facing: number,
	Flags: number,
	Health: number,
	MaxHealth: number,
	Resource: number,
	MaxResource: number,
	Shield: number,
	Epoch: number,
	Time: number,
}

const IDLE_ORDER: Order = { Kind = "Idle" }
-- The snapshot stream of players who see every unit.
const OPEN_STREAM = "All"

local Module = {}

-- (unit, killer)
Module.UnitDied = Signal.new() :: Signal.Signal<Unit, Unit?>
-- (target, source, damage dealt after armor, shield included, kind)
Module.UnitDamaged = Signal.new() :: Signal.Signal<Unit, Unit?, number, DamageKind>
Module.UnitRemoved = Signal.new() :: Signal.Signal<Unit>
-- (unit that blocked, source of the blocked hit)
Module.HitBlocked = Signal.new() :: Signal.Signal<Unit, Unit?>

local random = Random.new()
local unitsById: { [number]: Unit? } = {}
local unitArray: { Unit } = {}
local projectiles: { Projectile } = {}
-- What each snapshot stream (a team, or OPEN_STREAM) last got, by unit id.
local sentStates: { [string]: { [number]: SentState? } } = {}
local lastSyncTimes: { [Player]: number? } = {}
local pendingAdded: { UnitInfo } = {}
local pendingRemoved: { number } = {}
local hasRemovals = false
local isPaused = false
local lastUnitId = 0
local snapshotTimer = 0
local separationTimer = 0
local navigation: Navigation.Navigation? = nil
local shieldModifier: ((Unit, number, Unit?) -> number)? = nil
local visibility: Visibility? = nil

local function flatten(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

local function clearPath(unit: Unit)
	unit.Path = nil
	unit.PathGoal = nil
end

--[[
	Returns the point a unit walking to goal should head for now: the goal
	itself when nothing is in the way, else the next waypoint around the
	walls. The second result is true when that point is the goal.
]]
local function getSteerPoint(unit: Unit, goal: Vector3, now: number): (Vector3, boolean)
	local walls = navigation
	if not walls or Navigation.isClear(walls, unit.Position, goal) then
		clearPath(unit)
		return goal, true
	end

	local path = unit.Path
	local pathGoal = unit.PathGoal
	if
		not path
		or not pathGoal
		or now >= unit.NextPathTime
		or (goal - pathGoal).Magnitude > REPATH_DISTANCE
	then
		path = Navigation.findPath(walls, unit.Position, goal)
		unit.Path = path
		unit.PathGoal = goal
		unit.NextPathTime = now + REPATH_INTERVAL
	end
	assert(path, "A path was just found")

	while #path > 1 and (path[1] - unit.Position).Magnitude <= WAYPOINT_REACHED_DISTANCE do
		table.remove(path, 1)
	end
	return path[1], #path == 1
end

local function allocateUnitId(): number
	for _ = 1, MAX_UNIT_ID do
		lastUnitId = lastUnitId % MAX_UNIT_ID + 1
		if not unitsById[lastUnitId] then
			return lastUnitId
		end
	end
	error("Every unit id is in use")
end

local function toInfo(unit: Unit): UnitInfo
	return {
		Id = unit.Id,
		Kind = unit.Kind,
		TypeId = unit.TypeId,
		Team = unit.Team,
		Radius = unit.Stats.Radius,
		Position = unit.Position,
		Health = unit.Health,
		MaxHealth = unit.Stats.MaxHealth,
		OwnerUserId = if unit.OwnerPlayer then unit.OwnerPlayer.UserId else nil,
	}
end

local function recomputeStats(unit: Unit)
	local active: { StatModifier } = {}
	for _, timed in unit.Modifiers do
		table.insert(active, timed.Modifier)
	end

	local previousMaxHealth = unit.Stats.MaxHealth
	unit.Stats = CombatRules.applyModifiers(unit.BaseStats, active)
	if unit.Stats.MaxHealth ~= previousMaxHealth and previousMaxHealth > 0 then
		-- Keeps the same share of health when max health changes.
		unit.Health = unit.Health / previousMaxHealth * unit.Stats.MaxHealth
	end
end

local function expireModifiers(unit: Unit, now: number)
	local hasExpired = false
	for key, timed in unit.Modifiers do
		if now >= timed.ExpiresAt then
			unit.Modifiers[key] = nil
			hasExpired = true
		end
	end
	if hasExpired then
		recomputeStats(unit)
	end
end

local function faceToward(unit: Unit, point: Vector3)
	local offset = point - unit.Position
	if offset.X ~= 0 or offset.Z ~= 0 then
		unit.Facing = math.atan2(-offset.X, -offset.Z)
	end
end

--[[
	Moves the unit toward the point for one step at the given speed, and
	returns true once it is within stopDistance of it.
]]
local function moveToward(
	unit: Unit,
	point: Vector3,
	stopDistance: number,
	speed: number,
	dt: number
): boolean
	local offset = point - unit.Position
	local distance = offset.Magnitude
	if distance <= stopDistance then
		return true
	end
	if speed <= 0 then
		return false
	end

	local remaining = distance - stopDistance
	local stepLength = math.min(speed * dt, remaining)
	unit.Position += offset / distance * stepLength
	unit.Facing = math.atan2(-offset.X, -offset.Z)
	return stepLength >= remaining
end

local function clearCombatState(unit: Unit)
	-- Permanent modifiers (items) outlast death; buffs and slows do not.
	for key, timed in unit.Modifiers do
		if timed.ExpiresAt ~= math.huge then
			unit.Modifiers[key] = nil
		end
	end
	recomputeStats(unit)
	unit.Shield = 0
	unit.Dash = nil
	unit.StunnedUntil = 0
	unit.RootedUntil = 0
	unit.HealingCutUntil = 0
	unit.BlockedHits = 0
	unit.IsEnlarged = false
	unit.IsChanneling = false
end

local function killUnit(unit: Unit, killer: Unit?)
	unit.IsDead = true
	unit.Health = 0
	unit.Order = IDLE_ORDER
	clearCombatState(unit)
	Module.UnitDied:Fire(unit, killer)
	if unit.RemoveOnDeath then
		Module:RemoveUnit(unit)
	end
end

local function sendAttackFired(unit: Unit, target: Unit)
	local current = visibility
	if not current then
		UnitNetwork.AttackFired:FireAllClients(unit.Id, target.Id)
		return
	end
	-- An attack from out of sight would show where its attacker hides.
	for _, player in Players:GetPlayers() do
		-- Annotated because luau-lsp widens the narrowed team to string.
		local team: Team? = current.GetViewerTeam(player)
		if not team or Module:IsVisibleTo(unit, team) then
			UnitNetwork.AttackFired:FireClient(player, unit.Id, target.Id)
		end
	end
end

local function performAttack(unit: Unit, target: Unit)
	unit.AttackCooldown = unit.Stats.AttackInterval
	sendAttackFired(unit, target)

	local damage = CombatRules.rollAttackDamage(
		unit.Stats.AttackDamage,
		unit.Stats.CritChance,
		random:NextNumber()
	)
	local projectileSpeed = unit.Stats.ProjectileSpeed
	if projectileSpeed then
		table.insert(projectiles, {
			SourceId = unit.Id,
			TargetId = target.Id,
			Position = unit.Position,
			Speed = projectileSpeed,
			Damage = damage,
		})
	else
		Module:ApplyDamage(target, damage, unit, "Attack")
	end
end

local function stepDash(unit: Unit, dt: number)
	local dash = unit.Dash
	if not dash then
		return
	end
	if moveToward(unit, dash.Destination, 0, dash.Speed, dt) then
		unit.Dash = nil
		local onArrive = dash.OnArrive
		if onArrive then
			task.spawn(onArrive, unit)
		end
	end
end

local function stepOrder(unit: Unit, dt: number, now: number, canMove: boolean)
	local order = unit.Order
	local speed = if canMove then unit.Stats.MoveSpeed else 0
	if order.Kind == "Move" then
		local point, isGoal = getSteerPoint(unit, order.Target, now)
		if moveToward(unit, point, 0, speed, dt) and isGoal then
			unit.Order = IDLE_ORDER
			clearPath(unit)
		end
	elseif order.Kind == "Attack" then
		local target = unitsById[order.TargetId]
		if not target or not Module:CanAttack(unit, target) then
			unit.Order = IDLE_ORDER
			return
		end

		local reach = unit.Stats.AttackRange + unit.Stats.Radius + target.Stats.Radius
		if (target.Position - unit.Position).Magnitude > reach then
			if unit.BaseStats.MoveSpeed <= 0 then
				-- A tower can't follow a target out of its range.
				unit.Order = IDLE_ORDER
			else
				local point, isGoal = getSteerPoint(unit, target.Position, now)
				local stopDistance = if isGoal then reach - CHASE_SLACK else 0
				moveToward(unit, point, stopDistance, speed, dt)
			end
			return
		end

		faceToward(unit, target.Position)
		if unit.AttackCooldown <= 0 then
			performAttack(unit, target)
		end
	end
end

local function stepProjectiles(dt: number)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local target = unitsById[projectile.TargetId]
		local isFinished = not target or target.IsDead

		if target and not isFinished then
			local offset = target.Position - projectile.Position
			local distance = offset.Magnitude
			local stepLength = projectile.Speed * dt
			if distance <= stepLength + PROJECTILE_HIT_DISTANCE then
				Module:ApplyDamage(
					target,
					projectile.Damage,
					unitsById[projectile.SourceId],
					"Attack"
				)
				isFinished = true
			else
				projectile.Position += offset / distance * stepLength
			end
		end

		if isFinished then
			projectiles[index] = projectiles[#projectiles]
			projectiles[#projectiles] = nil
		end
	end
end

local function getCellKey(cellX: number, cellZ: number): number
	return (cellX + SEPARATION_CELL_OFFSET) * SEPARATION_CELL_OFFSET * 2
		+ cellZ
		+ SEPARATION_CELL_OFFSET
end

--[[
	Pushes overlapping units apart, so a wave doesn't collapse into one spot.
	A spatial grid keeps it to each unit's neighbors instead of every pair.
	Dashing units pass through others.
]]
local function separateUnits()
	local grid: { [number]: { Unit }? } = {}
	for _, unit in unitArray do
		if unit.IsRemoved or unit.IsDead or unit.Kind == "Summon" then
			continue
		end
		local key = getCellKey(
			unit.Position.X // SEPARATION_CELL_SIZE,
			unit.Position.Z // SEPARATION_CELL_SIZE
		)
		local cell = grid[key]
		if cell then
			table.insert(cell, unit)
		else
			grid[key] = { unit }
		end
	end

	for _, unit in unitArray do
		if
			unit.IsRemoved
			or unit.IsDead
			or unit.Dash
			or unit.Kind == "Summon"
			or unit.BaseStats.MoveSpeed <= 0
		then
			continue
		end

		local cellX = unit.Position.X // SEPARATION_CELL_SIZE
		local cellZ = unit.Position.Z // SEPARATION_CELL_SIZE
		local push = Vector3.zero
		for offsetX = -1, 1 do
			for offsetZ = -1, 1 do
				local cell = grid[getCellKey(cellX + offsetX, cellZ + offsetZ)]
				if not cell then
					continue
				end
				for _, other in cell do
					if other == unit or other.Dash then
						continue
					end
					local offset = unit.Position - other.Position
					local minimumDistance = unit.Stats.Radius + other.Stats.Radius
					local distance = offset.Magnitude
					if distance >= minimumDistance then
						continue
					end
					local direction = if distance > 0.001
						then offset / distance
						else Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)).Unit
					-- A unit that can't move takes none of the push.
					local share = if other.BaseStats.MoveSpeed > 0 then 0.5 else 1
					push += direction * (minimumDistance - distance) * share
				end
			end
		end
		unit.Position += push

		-- Walls win over crowding: a unit shoved or dashed into one is put
		-- back outside it.
		local walls = navigation
		if walls then
			unit.Position = Navigation.pushOut(walls, unit.Position, unit.Stats.Radius)
		end
	end
end

local function getFlags(unit: Unit, now: number): number
	local flags = 0
	if unit.IsDead then
		flags += UnitSnapshotCodec.Flags.Dead
	end
	if not unit.IsTargetable then
		flags += UnitSnapshotCodec.Flags.Untargetable
	end
	if now < unit.StunnedUntil then
		flags += UnitSnapshotCodec.Flags.Stunned
	end
	if now < unit.RootedUntil then
		flags += UnitSnapshotCodec.Flags.Rooted
	end
	if unit.IsEnlarged then
		flags += UnitSnapshotCodec.Flags.Enlarged
	end
	return flags
end

local function isSameState(sent: SentState, current: SentState): boolean
	return sent.X == current.X
		and sent.Z == current.Z
		and sent.Facing == current.Facing
		and sent.Flags == current.Flags
		and sent.Health == current.Health
		and sent.MaxHealth == current.MaxHealth
		and sent.Resource == current.Resource
		and sent.MaxResource == current.MaxResource
		and sent.Shield == current.Shield
		and sent.Epoch == current.Epoch
end

local function getVisibleState(unit: Unit, now: number): SentState
	return {
		X = UnitSnapshotCodec.quantizePosition(unit.Position.X),
		Z = UnitSnapshotCodec.quantizePosition(unit.Position.Z),
		Facing = UnitSnapshotCodec.quantizeFacing(unit.Facing),
		Flags = getFlags(unit, now),
		Health = UnitSnapshotCodec.quantizeAmount(unit.Health),
		MaxHealth = UnitSnapshotCodec.quantizeAmount(unit.Stats.MaxHealth),
		Resource = UnitSnapshotCodec.quantizeAmount(unit.Resource),
		MaxResource = UnitSnapshotCodec.quantizeAmount(unit.MaxResource),
		Shield = UnitSnapshotCodec.quantizeAmount(unit.Shield),
		Epoch = unit.MoveEpoch,
		Time = now,
	}
end

-- A hidden unit's entry carries nothing but the flag, so it gives away
-- neither where the unit is nor how it is doing.
local function getHiddenState(now: number): SentState
	return {
		X = 0,
		Z = 0,
		Facing = 0,
		Flags = UnitSnapshotCodec.Flags.Hidden,
		Health = 0,
		MaxHealth = 0,
		Resource = 0,
		MaxResource = 0,
		Shield = 0,
		Epoch = 0,
		Time = now,
	}
end

--[[
	Returns the entries a stream needs: every unit whose state changed since
	the stream last got it, or that it has not had for a while. Units team
	can't see go out hidden; a nil team sees every unit.
]]
local function buildEntries(stream: string, team: Team?, now: number): { UnitSnapshotCodec.Entry }
	local sent = sentStates[stream]
	if not sent then
		sent = {}
		sentStates[stream] = sent
	end

	local entries: { UnitSnapshotCodec.Entry } = {}
	for _, unit in unitArray do
		if unit.IsRemoved then
			continue
		end

		local isHidden = team ~= nil and not Module:IsVisibleTo(unit, team)
		local state = if isHidden then getHiddenState(now) else getVisibleState(unit, now)
		local previous = sent[unit.Id]
		if previous and now - previous.Time < REFRESH_INTERVAL and isSameState(previous, state) then
			continue
		end

		sent[unit.Id] = state
		if isHidden then
			table.insert(entries, {
				Id = unit.Id,
				X = 0,
				Z = 0,
				Facing = 0,
				Flags = state.Flags,
				Health = 0,
				MaxHealth = 0,
				Resource = 0,
				MaxResource = 0,
				Shield = 0,
				Epoch = 0,
			})
		else
			table.insert(entries, {
				Id = unit.Id,
				X = unit.Position.X,
				Z = unit.Position.Z,
				Facing = unit.Facing,
				Flags = state.Flags,
				Health = unit.Health,
				MaxHealth = unit.Stats.MaxHealth,
				Resource = unit.Resource,
				MaxResource = unit.MaxResource,
				Shield = unit.Shield,
				Epoch = unit.MoveEpoch,
			})
		end
	end
	return entries
end

--[[
	Groups players by the team whose sight they share. Players who see every
	unit share OPEN_STREAM.
]]
local function getStreams(current: Visibility): { [string]: { Player } }
	local streams: { [string]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		local team = current.GetViewerTeam(player)
		local stream = team or OPEN_STREAM
		local players = streams[stream]
		if players then
			table.insert(players, player)
		else
			streams[stream] = { player }
		end
	end
	return streams
end

local function sendSnapshots(now: number)
	local serverTime = workspace:GetServerTimeNow()
	local current = visibility
	if not current then
		local entries = buildEntries(OPEN_STREAM, nil, now)
		for _, payload in UnitSnapshotCodec.encode(serverTime, entries) do
			UnitNetwork.Snapshot:FireAllClients(payload)
		end
		return
	end

	for stream, players in getStreams(current) do
		local team: Team? = if stream == OPEN_STREAM then nil else stream :: Team
		local entries = buildEntries(stream, team, now)
		for _, payload in UnitSnapshotCodec.encode(serverTime, entries) do
			for _, player in players do
				UnitNetwork.Snapshot:FireClient(player, payload)
			end
		end
	end
end

local function flushRoster()
	if #pendingRemoved > 0 then
		UnitNetwork.UnitsRemoved:FireAllClients(pendingRemoved)
		pendingRemoved = {}
	end
	if #pendingAdded > 0 then
		UnitNetwork.UnitsAdded:FireAllClients(pendingAdded)
		pendingAdded = {}
	end
end

local function compactUnits()
	local kept = table.create(#unitArray)
	for _, unit in unitArray do
		if not unit.IsRemoved then
			table.insert(kept, unit)
		end
	end
	unitArray = kept
	hasRemovals = false
end

local function runBrain(unit: Unit, brain: (Unit) -> ())
	-- The cast gives pcall a second result to type, the error message.
	local success, message = pcall(brain :: (Unit) -> any, unit)
	if not success then
		-- Dropping the brain keeps one broken unit from warning every think.
		unit.Brain = nil
		warn(`Brain of unit {unit.Id} ({unit.TypeId}) failed and was removed: {message}`)
	end
end

local function stepUnit(unit: Unit, dt: number, now: number)
	if next(unit.Modifiers) then
		expireModifiers(unit, now)
	end
	if unit.Shield > 0 and now >= unit.ShieldExpiresAt then
		unit.Shield = 0
	end
	if unit.AttackCooldown > 0 then
		unit.AttackCooldown = math.max(unit.AttackCooldown - dt, 0)
	end
	-- A dash carries the unit through stuns and ignores its orders.
	if unit.Dash then
		stepDash(unit, dt)
		return
	end
	if now < unit.StunnedUntil then
		return
	end

	local brain = unit.Brain
	if brain and now >= unit.NextThinkTime then
		unit.NextThinkTime = now + THINK_INTERVAL
		runBrain(unit, brain)
	end
	stepOrder(unit, dt, now, now >= unit.RootedUntil)
end

local function step(frameTime: number)
	debug.profilebegin("UnitServerService:Step")
	local dt = math.min(frameTime, MAX_STEP)
	local now = os.clock()

	if not isPaused then
		-- Units spawned during the loop are appended past count and wait
		-- for the next step.
		local count = #unitArray
		for index = 1, count do
			local unit = unitArray[index]
			if not unit.IsRemoved and not unit.IsDead then
				stepUnit(unit, dt, now)
			end
		end

		stepProjectiles(dt)

		separationTimer += dt
		if separationTimer >= SEPARATION_INTERVAL then
			separationTimer = 0
			separateUnits()
		end
	end

	if hasRemovals then
		compactUnits()
	end
	flushRoster()

	snapshotTimer += frameTime
	if snapshotTimer >= UnitSnapshotCodec.SendInterval then
		snapshotTimer = 0
		sendSnapshots(now)
	end
	debug.profileend()
end

local function onSyncRequest(player: Player)
	local now = os.clock()
	local lastSyncTime = lastSyncTimes[player]
	if lastSyncTime and now - lastSyncTime < SYNC_COOLDOWN then
		return
	end
	lastSyncTimes[player] = now

	local infos = table.create(#unitArray)
	for _, unit in unitArray do
		if not unit.IsRemoved then
			table.insert(infos, toInfo(unit))
		end
	end
	UnitNetwork.UnitsAdded:FireClient(player, infos)
end

local function onPlayerRemoving(player: Player)
	lastSyncTimes[player] = nil
end

function Module:SpawnUnit(options: SpawnOptions): Unit
	local maxResource = options.MaxResource or 0
	local unit: Unit = {
		Id = allocateUnitId(),
		Kind = options.Kind,
		TypeId = options.TypeId,
		Team = options.Team,
		BaseStats = options.Stats,
		Stats = table.clone(options.Stats),
		Modifiers = {},
		Position = flatten(options.Position),
		Facing = 0,
		MoveEpoch = 0,
		Health = options.Stats.MaxHealth,
		Shield = 0,
		ShieldExpiresAt = 0,
		Resource = maxResource,
		MaxResource = maxResource,
		IsDead = false,
		IsRemoved = false,
		IsTargetable = if options.IsTargetable == nil then true else options.IsTargetable,
		IsChanneling = false,
		RemoveOnDeath = if options.RemoveOnDeath == nil then true else options.RemoveOnDeath,
		OwnerPlayer = options.OwnerPlayer,
		Order = IDLE_ORDER,
		Dash = nil,
		StunnedUntil = 0,
		RootedUntil = 0,
		CrowdControlImmuneUntil = 0,
		HealingCutUntil = 0,
		BlockedHits = 0,
		BlockUntil = 0,
		IsEnlarged = false,
		AttackCooldown = 0,
		Path = nil,
		PathGoal = nil,
		NextPathTime = 0,
		Brain = options.Brain,
		-- Spread first thinks out, so a whole wave doesn't think on one frame.
		NextThinkTime = os.clock() + random:NextNumber(0, THINK_INTERVAL),
	}

	unitsById[unit.Id] = unit
	table.insert(unitArray, unit)
	table.insert(pendingAdded, toInfo(unit))
	return unit
end

function Module:RemoveUnit(unit: Unit)
	if unit.IsRemoved then
		return
	end

	unit.IsRemoved = true
	unitsById[unit.Id] = nil
	for _, sent in sentStates do
		sent[unit.Id] = nil
	end
	hasRemovals = true

	-- A unit removed in the step it spawned was never announced, so clients
	-- are told nothing. Sending both would deliver the removal first, and
	-- the client would keep a ghost of a unit that no longer exists.
	local unsentIndex: number? = nil
	for index, info in pendingAdded do
		if info.Id == unit.Id then
			unsentIndex = index
			break
		end
	end
	if unsentIndex then
		table.remove(pendingAdded, unsentIndex)
	else
		table.insert(pendingRemoved, unit.Id)
	end
	Module.UnitRemoved:Fire(unit)
end

function Module:GetUnit(unitId: number): Unit?
	return unitsById[unitId]
end

--[[
	Returns the live list of units, which can include removed units until the
	end of the current step. Read it; never change it.
]]
function Module:GetUnits(): { Unit }
	return unitArray
end

function Module:FindOwnedHero(player: Player): Unit?
	for _, unit in unitArray do
		if unit.Kind == "Hero" and unit.OwnerPlayer == player and not unit.IsRemoved then
			return unit
		end
	end
	return nil
end

--[[
	Returns the live unit closest to the position whose edge is within radius
	and that passes the predicate.
]]
function Module:FindNearest(position: Vector3, radius: number, predicate: (Unit) -> boolean): Unit?
	local nearest: Unit? = nil
	local nearestDistance = math.huge
	for _, unit in unitArray do
		if unit.IsRemoved or unit.IsDead then
			continue
		end
		local distance = (unit.Position - position).Magnitude - unit.Stats.Radius
		if distance <= radius and distance < nearestDistance and predicate(unit) then
			nearest = unit
			nearestDistance = distance
		end
	end
	return nearest
end

--[[
	Returns every live unit whose edge is within radius of the position and
	that passes the predicate.
]]
function Module:FindInRadius(
	position: Vector3,
	radius: number,
	predicate: (Unit) -> boolean
): { Unit }
	local found = {}
	for _, unit in unitArray do
		if unit.IsRemoved or unit.IsDead then
			continue
		end
		if
			(unit.Position - position).Magnitude - unit.Stats.Radius <= radius and predicate(unit)
		then
			table.insert(found, unit)
		end
	end
	return found
end

function Module:IsEnemy(unit: Unit, other: Unit): boolean
	return unit.Team ~= other.Team
end

function Module:CanAttack(attacker: Unit, target: Unit): boolean
	return not target.IsDead
		and not target.IsRemoved
		and target.IsTargetable
		and attacker.Team ~= target.Team
		and attacker.Stats.AttackDamage > 0
		and Module:IsVisibleTo(target, attacker.Team)
end

--[[
	Whether a team can see the unit. Without fog of war every unit is seen.
]]
function Module:IsVisibleTo(unit: Unit, team: Team): boolean
	local current = visibility
	return current == nil or unit.Team == team or current.IsUnitVisible(unit, team)
end

function Module:IsPointVisibleTo(position: Vector3, team: Team): boolean
	local current = visibility
	return current == nil or current.IsPointVisible(position, team)
end

--[[
	Returns the team whose sight the player shares, or nil when the player
	sees everything.
]]
function Module:GetViewerTeam(player: Player): Team?
	local current = visibility
	return if current then current.GetViewerTeam(player) else nil
end

--[[
	Turns on fog of war: units out of a team's sight are left out of that
	team's snapshots and can't be attacked by it. Nil turns it off.
]]
function Module:SetVisibility(newVisibility: Visibility?)
	visibility = newVisibility
end

function Module:IsStunned(unit: Unit): boolean
	return os.clock() < unit.StunnedUntil
end

function Module:IssueOrder(unit: Unit, order: Order)
	unit.Order = order
	clearPath(unit)
end

--[[
	Deals damage and returns the amount dealt. Attack and Ability damage are
	reduced by armor, and a shield absorbs damage before health. A dead or
	untargetable target takes none.
]]
function Module:ApplyDamage(target: Unit, amount: number, source: Unit?, kind: DamageKind): number
	if target.IsDead or target.IsRemoved or not target.IsTargetable or amount <= 0 then
		return 0
	end
	if kind ~= "True" and target.BlockedHits > 0 and os.clock() < target.BlockUntil then
		target.BlockedHits -= 1
		Module.HitBlocked:Fire(target, source)
		return 0
	end

	local amplified = if kind == "Ability" and source
		then CombatRules.amplifyAbilityDamage(amount, source.Stats.AbilityPower)
		else amount
	local mitigated = if kind == "True"
		then amplified
		else CombatRules.mitigateDamage(amplified, target.Stats.Armor)
	local absorbed = math.min(target.Shield, mitigated)
	target.Shield -= absorbed
	local healthLoss = math.min(mitigated - absorbed, target.Health)
	target.Health -= healthLoss

	local dealt = absorbed + healthLoss
	Module.UnitDamaged:Fire(target, source, dealt, kind)
	if target.Health <= 0 then
		killUnit(target, source)
	end
	return dealt
end

function Module:Heal(unit: Unit, amount: number)
	if unit.IsDead or unit.IsRemoved then
		return
	end
	local share = if os.clock() < unit.HealingCutUntil then HEALING_CUT_SHARE else 1
	unit.Health = math.min(unit.Health + amount * share, unit.Stats.MaxHealth)
end

function Module:SetResource(unit: Unit, amount: number)
	unit.Resource = math.clamp(amount, 0, unit.MaxResource)
end

--[[
	Changes a unit's resource pool, such as on a level up, keeping the same
	share of it full.
]]
function Module:SetMaxResource(unit: Unit, maximum: number)
	local share = if unit.MaxResource > 0 then unit.Resource / unit.MaxResource else 1
	unit.MaxResource = math.max(maximum, 0)
	unit.Resource = unit.MaxResource * share
end

function Module:RestoreResource(unit: Unit, amount: number)
	if unit.IsDead or unit.IsRemoved then
		return
	end
	unit.Resource = math.min(unit.Resource + amount, unit.MaxResource)
end

--[[
	Replaces a unit's stats before modifiers, such as on a level up.
]]
function Module:SetBaseStats(unit: Unit, stats: UnitStats)
	unit.BaseStats = stats
	recomputeStats(unit)
end

--[[
	Adds or replaces the modifier under key for duration seconds. Reusing a
	key refreshes it instead of stacking a second copy. A dead unit takes
	only permanent modifiers (duration math.huge), the kind that outlast death.
]]
function Module:AddModifier(unit: Unit, key: string, modifier: StatModifier, duration: number)
	if unit.IsRemoved or (unit.IsDead and duration ~= math.huge) then
		return
	end
	unit.Modifiers[key] = {
		Modifier = modifier,
		ExpiresAt = os.clock() + duration,
	}
	recomputeStats(unit)
end

function Module:RemoveModifier(unit: Unit, key: string)
	if unit.Modifiers[key] then
		unit.Modifiers[key] = nil
		recomputeStats(unit)
	end
end

--[[
	Ends every stun, root, and slow on the unit.
]]
function Module:ClearImpairments(unit: Unit)
	unit.StunnedUntil = 0
	unit.RootedUntil = 0
	local hasRemoved = false
	for key, timed in unit.Modifiers do
		local modifier = timed.Modifier
		if
			modifier.Stat == "MoveSpeed"
			and ((modifier.Multiply or 1) < 1 or (modifier.Add or 0) < 0)
		then
			unit.Modifiers[key] = nil
			hasRemoved = true
		end
	end
	if hasRemoved then
		recomputeStats(unit)
	end
end

function Module:GrantCrowdControlImmunity(unit: Unit, duration: number)
	unit.CrowdControlImmuneUntil = math.max(unit.CrowdControlImmuneUntil, os.clock() + duration)
end

function Module:Stun(unit: Unit, duration: number)
	local now = os.clock()
	if now < unit.CrowdControlImmuneUntil or unit.IsDead then
		return
	end
	unit.StunnedUntil = math.max(unit.StunnedUntil, now + duration)
end

function Module:Root(unit: Unit, duration: number, options: RootOptions?)
	local now = os.clock()
	local isSelfApplied = options and options.IsSelfApplied
	if unit.IsDead or (now < unit.CrowdControlImmuneUntil and not isSelfApplied) then
		return
	end
	unit.RootedUntil = math.max(unit.RootedUntil, now + duration)
end

--[[
	Makes the unit shrug off its next few Attack and Ability hits for
	duration seconds, firing HitBlocked for each. True damage still lands.
]]
function Module:BlockHits(unit: Unit, hits: number, duration: number)
	if unit.IsDead or unit.IsRemoved then
		return
	end
	unit.BlockedHits = hits
	unit.BlockUntil = os.clock() + duration
end

--[[
	Grows the unit huge on every client, or back to its size. It changes how
	the unit looks, not its footprint.
]]
function Module:SetEnlarged(unit: Unit, isEnlarged: boolean)
	unit.IsEnlarged = isEnlarged
end

function Module:CutHealing(unit: Unit, duration: number)
	unit.HealingCutUntil = math.max(unit.HealingCutUntil, os.clock() + duration)
end

--[[
	Adds a shield that absorbs damage for duration seconds. Shields from
	several sources add up and last as long as the longest one. The caster's
	shield power makes the shields it casts stronger.
]]
function Module:AddShield(unit: Unit, amount: number, duration: number, caster: Unit?)
	if unit.IsDead or unit.IsRemoved then
		return
	end
	local strength = amount
	if caster then
		strength *= 1 + (caster.Stats.ShieldPower or 0) / 100
	end
	local modify = shieldModifier
	if modify then
		strength = modify(unit, strength, caster)
	end
	unit.Shield += strength
	unit.ShieldExpiresAt = math.max(unit.ShieldExpiresAt, os.clock() + duration)
end

--[[
	Sets a game rule that changes each shield as it is cast: it gets the
	shielded unit, the shield's strength, and the caster, and returns the
	strength to use.
]]
function Module:SetShieldModifier(modify: (Unit, number, Unit?) -> number)
	shieldModifier = modify
end

--[[
	Sends the unit straight to a point at the given speed (studs per second),
	ignoring its orders, then calls onArrive. The unit is left idle.
]]
function Module:Dash(unit: Unit, destination: Vector3, speed: number, onArrive: ((Unit) -> ())?)
	if unit.IsDead or unit.IsRemoved then
		return
	end
	unit.Order = IDLE_ORDER
	clearPath(unit)
	unit.Dash = {
		Destination = flatten(destination),
		Speed = speed,
		OnArrive = onArrive,
	}
end

--[[
	Moves the unit to a point at once. Clients jump it there instead of
	sliding it across the map.
]]
function Module:Teleport(unit: Unit, position: Vector3)
	if unit.IsRemoved then
		return
	end
	unit.Position = flatten(position)
	unit.Dash = nil
	unit.Order = IDLE_ORDER
	clearPath(unit)
	unit.MoveEpoch = (unit.MoveEpoch + 1) % MOVE_EPOCH_COUNT
end

function Module:Revive(unit: Unit, position: Vector3)
	if unit.IsRemoved then
		return
	end

	unit.IsDead = false
	clearCombatState(unit)
	unit.Health = unit.Stats.MaxHealth
	unit.Resource = unit.MaxResource
	unit.AttackCooldown = 0
	Module:Teleport(unit, position)
end

function Module:SetTargetable(unit: Unit, isTargetable: boolean)
	unit.IsTargetable = isTargetable
end

--[[
	Freezes every unit in place. Snapshots keep flowing, so clients still see
	the final state.
]]
function Module:SetPaused(paused: boolean)
	isPaused = paused
end

--[[
	Sets the walls units walk around and can't stand in. Paths keep
	clearance studs from every wall, so it should be at least the largest
	walking unit's radius. Dashes pass over walls and land outside them.
]]
function Module:SetWalls(walls: { Navigation.Wall }, clearance: number)
	assert(clearance > 0, "The wall clearance must be positive")
	navigation = if #walls > 0 then Navigation.new(walls, clearance) else nil
	for _, unit in unitArray do
		clearPath(unit)
	end
end

function Module:Init()
	UnitNetwork.SyncRequest.OnServerEvent:Connect(onSyncRequest)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function Module:Start()
	RunService.Heartbeat:Connect(step)
end

return Module
