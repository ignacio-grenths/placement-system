--!strict

const RunService = game:GetService("RunService")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

-- Studs from its spot within which a monster counts as home.
const HOME_DISTANCE = 1.5

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit
type UnitStats = UnitTypes.UnitStats

export type MonsterOptions = {
	TypeId: string,
	Stats: UnitStats,
	-- Where the monster stands while no one fights it.
	Position: Vector3,
}

export type CampOptions = {
	-- Unique among registered camps.
	Key: string,
	-- What CampCleared reports the camp as, such as "CrystalGolem".
	Kind: string,
	Position: Vector3,
	Monsters: { MonsterOptions },
	-- Seconds on the match clock before the camp first appears.
	FirstSpawnTime: number,
	-- Seconds after the camp is cleared before it comes back.
	RespawnDelay: number,
}

type Camp = {
	Options: CampOptions,
	Monsters: { Unit },
	-- The unit the whole camp fights. Nil while it rests.
	TargetId: number?,
	-- Match clock second the camp appears next. Nil while it is up.
	NextSpawnTime: number?,
}

type Monster = {
	Camp: Camp,
	Home: Vector3,
	IsReturning: boolean,
}

local Module = {}

-- (camp key, camp kind, the unit that landed the last hit)
Module.CampCleared = Signal.new() :: Signal.Signal<string, string, Unit?>

local camps: { [string]: Camp } = {}
local monsters: { [Unit]: Monster? } = {}
local leashRadius = 22
local matchStartTime: number? = nil

local function moveTo(unit: Unit, point: Vector3)
	local order = unit.Order
	if order.Kind ~= "Move" or order.Target ~= point then
		UnitServerService:IssueOrder(unit, { Kind = "Move", Target = point })
	end
end

--[[
	Sends the whole camp home. Monsters can't be hit on the way, so a camp
	pulled past its leash can't be finished off as it walks back.
]]
local function leash(camp: Camp)
	camp.TargetId = nil
	for _, unit in camp.Monsters do
		local monster = monsters[unit]
		if monster then
			monster.IsReturning = true
			UnitServerService:SetTargetable(unit, false)
		end
	end
end

local function findCampTarget(camp: Camp, unit: Unit): Unit?
	local targetId = camp.TargetId
	local target = if targetId then UnitServerService:GetUnit(targetId) else nil
	if
		target
		and UnitServerService:CanAttack(unit, target)
		and (target.Position - camp.Options.Position).Magnitude <= leashRadius
	then
		return target
	end
	return nil
end

local function createBrain(monster: Monster): (Unit) -> ()
	local camp = monster.Camp

	return function(unit: Unit)
		local isHome = (unit.Position - monster.Home).Magnitude <= HOME_DISTANCE
		if monster.IsReturning then
			if isHome then
				monster.IsReturning = false
				-- math.huge heals to full through any healing cut.
				UnitServerService:Heal(unit, math.huge)
				UnitServerService:SetTargetable(unit, true)
			else
				moveTo(unit, monster.Home)
			end
			return
		end

		local target = findCampTarget(camp, unit)
		if target then
			local order = unit.Order
			if order.Kind ~= "Attack" or order.TargetId ~= target.Id then
				UnitServerService:IssueOrder(unit, { Kind = "Attack", TargetId = target.Id })
			end
		elseif camp.TargetId then
			-- The target died, hid, or left the leash.
			leash(camp)
		elseif not isHome then
			moveTo(unit, monster.Home)
		end
	end
end

local function spawnCamp(camp: Camp)
	camp.NextSpawnTime = nil
	camp.TargetId = nil
	camp.Monsters = {}
	for _, options in camp.Options.Monsters do
		local monster: Monster = {
			Camp = camp,
			Home = options.Position,
			IsReturning = false,
		}
		local unit = UnitServerService:SpawnUnit({
			Kind = "Monster",
			TypeId = options.TypeId,
			Team = "Neutral",
			Stats = options.Stats,
			Position = options.Position,
			Brain = createBrain(monster),
		})
		monsters[unit] = monster
		table.insert(camp.Monsters, unit)
	end
end

local function removeMonsters()
	for _, camp in camps do
		for _, unit in camp.Monsters do
			monsters[unit] = nil
			UnitServerService:RemoveUnit(unit)
		end
		camp.Monsters = {}
		camp.TargetId = nil
	end
end

local function getElapsed(): number?
	local startTime = matchStartTime
	return if startTime then workspace:GetServerTimeNow() - startTime else nil
end

local function onUnitDamaged(target: Unit, source: Unit?)
	local monster = monsters[target]
	if not monster or not source or monster.IsReturning then
		return
	end

	-- A camp keeps fighting whoever it already fights while they stay in reach.
	local camp = monster.Camp
	if findCampTarget(camp, target) then
		return
	end
	if source.Team ~= target.Team then
		camp.TargetId = source.Id
	end
end

local function onUnitDied(unit: Unit, killer: Unit?)
	local monster = monsters[unit]
	if not monster then
		return
	end
	monsters[unit] = nil

	local camp = monster.Camp
	local index = table.find(camp.Monsters, unit)
	if index then
		table.remove(camp.Monsters, index)
	end
	if #camp.Monsters > 0 then
		return
	end

	local elapsed = getElapsed()
	if elapsed then
		camp.NextSpawnTime = elapsed + camp.Options.RespawnDelay
	end
	Module.CampCleared:Fire(camp.Options.Key, camp.Options.Kind, killer)
end

local function step()
	local elapsed = getElapsed()
	if not elapsed then
		return
	end

	for _, camp in camps do
		local spawnTime = camp.NextSpawnTime
		if spawnTime and elapsed >= spawnTime then
			spawnCamp(camp)
		end
	end
end

function Module:RegisterCamp(options: CampOptions)
	assert(#options.Monsters > 0, "A camp needs at least one monster")
	if camps[options.Key] then
		error(`A camp is already registered as {options.Key}`)
	end
	camps[options.Key] = {
		Options = options,
		Monsters = {},
		TargetId = nil,
		NextSpawnTime = options.FirstSpawnTime,
	}
end

--[[
	Sets how far, in studs from its camp, a target can go before the camp
	gives up on it and goes home.
]]
function Module:SetLeashRadius(radius: number)
	assert(radius > 0, "The leash radius must be positive")
	leashRadius = radius
end

--[[
	Returns the camp's living monsters, empty while it is down.
]]
function Module:GetCampMonsters(key: string): { Unit }
	local camp = camps[key]
	return if camp then table.clone(camp.Monsters) else {}
end

--[[
	Clears every camp and starts spawning them on a match clock that starts
	at a server time (workspace:GetServerTimeNow()).
]]
function Module:Begin(startTime: number)
	removeMonsters()
	matchStartTime = startTime
	for _, camp in camps do
		camp.NextSpawnTime = camp.Options.FirstSpawnTime
	end
end

function Module:Stop()
	matchStartTime = nil
end

function Module:Init()
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitDied:Connect(onUnitDied)
end

function Module:Start()
	RunService.Heartbeat:Connect(step)
end

return Module
