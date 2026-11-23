--!strict

const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const UnitNetwork = require("./UnitNetwork")
const UnitSnapshotCodec = require("./UnitSnapshotCodec")

-- Units are drawn this many seconds in the past, so there is nearly always a
-- later snapshot to blend toward.
const INTERPOLATION_DELAY = 0.12
const MAX_SAMPLES = 8
-- A gap between snapshots longer than this many send intervals means the
-- server skipped the unit because it stood still.
const STILL_GAP_INTERVALS = 1.5

const UnitTypes = require("./UnitTypes")

type Team = UnitTypes.Team
type UnitInfo = UnitTypes.UnitInfo
type UnitKind = UnitTypes.UnitKind

type Sample = {
	Time: number,
	Position: Vector3,
	Facing: number,
}

export type ClientUnit = {
	Id: number,
	Kind: UnitKind,
	TypeId: string,
	Team: Team,
	Radius: number,
	OwnerUserId: number?,
	Health: number,
	MaxHealth: number,
	Resource: number,
	MaxResource: number,
	Shield: number,
	IsDead: boolean,
	IsTargetable: boolean,
	IsStunned: boolean,
	IsRooted: boolean,
	IsEnlarged: boolean,
	-- The server's MoveEpoch from the last snapshot, or -1 before the first.
	Epoch: number,
	-- Server-time samples, oldest first. Never empty.
	Samples: { Sample },
}

local Module = {}

Module.UnitAdded = Signal.new() :: Signal.Signal<ClientUnit>
Module.UnitRemoved = Signal.new() :: Signal.Signal<ClientUnit>
-- (attacker, target)
Module.AttackFired = Signal.new() :: Signal.Signal<ClientUnit, ClientUnit>

local units: { [number]: ClientUnit? } = {}
local localHeroId: number? = nil

local function lerpAngle(from: number, to: number, alpha: number): number
	local difference = (to - from + math.pi) % (math.pi * 2) - math.pi
	return from + difference * alpha
end

local function addSample(unit: ClientUnit, sample: Sample, isTeleport: boolean)
	local samples = unit.Samples
	local latest = samples[#samples]
	if isTeleport then
		table.clear(samples)
	elseif latest then
		-- The server skips units that did not change, so a long gap means the
		-- unit stood at its last sample until just before this one. Without
		-- this hold, the blend would stretch one step across the whole gap.
		if sample.Time - latest.Time > UnitSnapshotCodec.SendInterval * STILL_GAP_INTERVALS then
			table.insert(samples, {
				Time = sample.Time - UnitSnapshotCodec.SendInterval,
				Position = latest.Position,
				Facing = latest.Facing,
			})
		end
	end

	table.insert(samples, sample)
	while #samples > MAX_SAMPLES do
		table.remove(samples, 1)
	end
end

local function onUnitsAdded(infos: { UnitInfo })
	for _, info in infos do
		-- A sync resends units this client already knows.
		if units[info.Id] then
			continue
		end

		local unit: ClientUnit = {
			Id = info.Id,
			Kind = info.Kind,
			TypeId = info.TypeId,
			Team = info.Team,
			Radius = info.Radius,
			OwnerUserId = info.OwnerUserId,
			Health = info.Health,
			MaxHealth = info.MaxHealth,
			Resource = 0,
			MaxResource = 0,
			Shield = 0,
			IsDead = false,
			IsTargetable = true,
			IsStunned = false,
			IsRooted = false,
			IsEnlarged = false,
			Epoch = -1,
			-- Time zero sorts before any snapshot, so the first snapshot
			-- blends from the spawn point.
			Samples = {
				{ Time = 0, Position = info.Position, Facing = 0 },
			},
		}
		units[info.Id] = unit
		Module.UnitAdded:Fire(unit)
	end
end

local function onUnitsRemoved(unitIds: { number })
	for _, unitId in unitIds do
		local unit = units[unitId]
		if not unit then
			continue
		end

		units[unitId] = nil
		if localHeroId == unitId then
			localHeroId = nil
		end
		Module.UnitRemoved:Fire(unit)
	end
end

local function onSnapshot(payload: buffer)
	local serverTime, entries = UnitSnapshotCodec.decode(payload)
	for _, entry in entries do
		local unit = units[entry.Id]
		if not unit then
			continue
		end

		-- Unreliable packets can arrive late; a stale one would undo newer state.
		local latest = unit.Samples[#unit.Samples]
		if latest and serverTime <= latest.Time then
			continue
		end

		-- A new epoch means the server teleported the unit (a blink, a recall,
		-- a revive), so it jumps instead of sliding across the map.
		local isTeleport = unit.Epoch >= 0 and entry.Epoch ~= unit.Epoch
		unit.Epoch = entry.Epoch
		unit.IsDead = bit32.btest(entry.Flags, UnitSnapshotCodec.Flags.Dead)
		unit.IsTargetable = not bit32.btest(entry.Flags, UnitSnapshotCodec.Flags.Untargetable)
		unit.IsStunned = bit32.btest(entry.Flags, UnitSnapshotCodec.Flags.Stunned)
		unit.IsRooted = bit32.btest(entry.Flags, UnitSnapshotCodec.Flags.Rooted)
		unit.IsEnlarged = bit32.btest(entry.Flags, UnitSnapshotCodec.Flags.Enlarged)
		unit.Health = entry.Health
		unit.MaxHealth = entry.MaxHealth
		unit.Resource = entry.Resource
		unit.MaxResource = entry.MaxResource
		unit.Shield = entry.Shield

		addSample(unit, {
			Time = serverTime,
			Position = Vector3.new(entry.X, 0, entry.Z),
			Facing = entry.Facing,
		}, isTeleport)
	end
end

local function onAttackFired(attackerId: number, targetId: number)
	local attacker = units[attackerId]
	local target = units[targetId]
	if attacker and target then
		Module.AttackFired:Fire(attacker, target)
	end
end

function Module:GetUnit(unitId: number): ClientUnit?
	return units[unitId]
end

function Module:GetUnits(): { [number]: ClientUnit? }
	return units
end

function Module:GetLocalHero(): ClientUnit?
	if localHeroId then
		local hero = units[localHeroId]
		if hero then
			return hero
		end
	end

	local userId = Players.LocalPlayer.UserId
	for unitId, unit in units do
		if unit and unit.Kind == "Hero" and unit.OwnerUserId == userId then
			localHeroId = unitId
			return unit
		end
	end
	return nil
end

--[[
	Returns the server time the world is drawn at this frame.
]]
function Module:GetRenderTime(): number
	return workspace:GetServerTimeNow() - INTERPOLATION_DELAY
end

--[[
	Returns the unit's position and facing at a server time, blended between
	the samples around it. Past the newest sample, the unit holds there.
]]
function Module:GetRenderPose(unit: ClientUnit, renderTime: number): (Vector3, number)
	local samples = unit.Samples
	for index = #samples, 1, -1 do
		local sample = samples[index]
		if sample.Time <= renderTime then
			local nextSample = samples[index + 1]
			if not nextSample then
				return sample.Position, sample.Facing
			end
			local alpha = (renderTime - sample.Time) / (nextSample.Time - sample.Time)
			return sample.Position:Lerp(nextSample.Position, alpha),
				lerpAngle(sample.Facing, nextSample.Facing, alpha)
		end
	end

	local oldest = samples[1]
	return oldest.Position, oldest.Facing
end

function Module:Init()
	UnitNetwork.UnitsAdded.OnClientEvent:Connect(onUnitsAdded)
	UnitNetwork.UnitsRemoved.OnClientEvent:Connect(onUnitsRemoved)
	UnitNetwork.Snapshot.OnClientEvent:Connect(onSnapshot)
	UnitNetwork.AttackFired.OnClientEvent:Connect(onAttackFired)
end

function Module:Start()
	-- Asked for after every Init has connected, so no system misses a unit.
	UnitNetwork.SyncRequest:FireServer()
end

return Module
