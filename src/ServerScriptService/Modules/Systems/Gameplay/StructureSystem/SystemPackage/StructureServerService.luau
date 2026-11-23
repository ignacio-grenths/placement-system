--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const StructureRules = require("./StructureRules")

-- Seconds before a destroyed gate rebuilds.
const GATE_REBUILD_DELAY = 240
-- Seconds a hero who hit an allied hero stays a tower's first target.
const AGGRESSION_MEMORY = 2

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Team = UnitTypes.Team
type Tier = StructureRules.Tier
type Unit = UnitTypes.Unit
type UnitStats = UnitTypes.UnitStats

export type StructureDefinition = {
	Id: string,
	Team: Team,
	-- Nil for the core, which belongs to no lane.
	Lane: string?,
	Tier: Tier,
	TypeId: string,
	Stats: UnitStats,
	Position: Vector3,
}

local Module = {}

-- (team that lost it, lane)
Module.GateDestroyed = Signal.new() :: Signal.Signal<Team, string>
-- (team that owns it, lane)
Module.GateRebuilt = Signal.new() :: Signal.Signal<Team, string>
-- (team that lost it)
Module.CoreDestroyed = Signal.new() :: Signal.Signal<Team>

local definitions: { StructureDefinition } = {}
local laneNames: { string } = {}
local definitionsByUnit: { [Unit]: StructureDefinition? } = {}
local liveUnits: { [StructureDefinition]: Unit? } = {}
local downKeys: { [string]: boolean? } = {}
local lastAggressionTimes: { [number]: number? } = {}

local function getDownKey(team: Team, lane: string, tier: Tier): string
	return `{team}:{lane}:{tier}`
end

local function refreshExposure()
	for definition, unit in liveUnits do
		if not unit then
			continue
		end
		local function isDown(lane: string, tier: Tier): boolean
			return downKeys[getDownKey(definition.Team, lane, tier)] == true
		end
		local isExposed =
			StructureRules.isExposed(definition.Tier, definition.Lane, isDown, laneNames)
		UnitServerService:SetTargetable(unit, isExposed)
	end
end

local function towerBrain(tower: Unit)
	local now = SimClock.now()
	local reach = tower.Stats.AttackRange + tower.Stats.Radius
	-- Towers leave jungle monsters to the heroes who pulled them, and wards
	-- to heroes too.
	local enemies = UnitServerService:FindInRadius(tower.Position, reach, function(other)
		return other.Kind ~= "Monster"
			and other.Kind ~= "Ward"
			and UnitServerService:CanAttack(tower, other)
	end)

	local candidates: { StructureRules.TargetCandidate } = table.create(#enemies)
	for _, enemy in enemies do
		local lastAggressionTime = lastAggressionTimes[enemy.Id]
		table.insert(candidates, {
			Id = enemy.Id,
			IsHero = enemy.Kind == "Hero",
			IsAggressor = lastAggressionTime ~= nil
				and now - lastAggressionTime <= AGGRESSION_MEMORY,
			Distance = (enemy.Position - tower.Position).Magnitude,
		})
	end

	local order = tower.Order
	local currentTargetId = if order.Kind == "Attack" then order.TargetId else nil
	local targetId = StructureRules.chooseTowerTarget(candidates, currentTargetId)
	if targetId then
		if targetId ~= currentTargetId then
			UnitServerService:IssueOrder(tower, { Kind = "Attack", TargetId = targetId })
		end
	elseif order.Kind ~= "Idle" then
		UnitServerService:IssueOrder(tower, { Kind = "Idle" })
	end
end

local function spawnStructure(definition: StructureDefinition)
	local unit = UnitServerService:SpawnUnit({
		Kind = "Structure",
		TypeId = definition.TypeId,
		Team = definition.Team,
		Stats = definition.Stats,
		Position = definition.Position,
		Brain = if definition.Stats.AttackDamage > 0 then towerBrain else nil,
		IsTargetable = false,
	})
	definitionsByUnit[unit] = definition
	liveUnits[definition] = unit
end

local function rebuildGate(definition: StructureDefinition, lane: string)
	downKeys[getDownKey(definition.Team, lane, definition.Tier)] = nil
	spawnStructure(definition)
	refreshExposure()
	Module.GateRebuilt:Fire(definition.Team, lane)
end

local function onUnitDied(unit: Unit)
	local definition = definitionsByUnit[unit]
	if not definition then
		return
	end

	definitionsByUnit[unit] = nil
	liveUnits[definition] = nil
	local lane = definition.Lane
	downKeys[getDownKey(definition.Team, lane or "", definition.Tier)] = true

	if definition.Tier == "Gate" and lane then
		Module.GateDestroyed:Fire(definition.Team, lane)
		SimClock.delay(GATE_REBUILD_DELAY, rebuildGate, definition, lane)
	elseif definition.Tier == "Core" then
		Module.CoreDestroyed:Fire(definition.Team)
	end
	refreshExposure()
end

local function onUnitDamaged(target: Unit, source: Unit?)
	if
		source
		and source.Kind == "Hero"
		and target.Kind == "Hero"
		and source.Team ~= target.Team
	then
		lastAggressionTimes[source.Id] = SimClock.now()
	end
end

local function onUnitRemoved(unit: Unit)
	lastAggressionTimes[unit.Id] = nil
end

function Module:RegisterStructure(definition: StructureDefinition)
	table.insert(definitions, definition)
end

--[[
	Sets the lanes whose gates open the core.
]]
function Module:SetLanes(lanes: { string })
	laneNames = table.clone(lanes)
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitRemoved:Connect(onUnitRemoved)
end

function Module:Start()
	for _, definition in definitions do
		spawnStructure(definition)
	end
	refreshExposure()
end

return Module
