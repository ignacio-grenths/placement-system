--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

-- Seconds a dead hero waits before reviving at its fountain. It will grow
-- with level once heroes level up.
const RESPAWN_DELAY = 8
const FOUNTAIN_TICK = 0.5
-- Share of max health and resource the fountain restores each tick.
const FOUNTAIN_RESTORE_SHARE = 0.1

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Team = UnitTypes.Team
type Unit = UnitTypes.Unit
type UnitStats = UnitTypes.UnitStats

export type HeroDefinition = {
	Stats: UnitStats,
	MaxResource: number,
}

type Fountain = {
	Position: Vector3,
	Radius: number,
}

local Module = {}

-- (hero unit, hero id)
Module.HeroSpawned = Signal.new() :: Signal.Signal<Unit, string>
Module.HeroRemoved = Signal.new() :: Signal.Signal<Unit>

local definitions: { [string]: HeroDefinition? } = {}
local fountains: { [Team]: Fountain? } = {}
local heroes: { [Player]: Unit? } = {}

--[[
	An idle hero attacks the nearest enemy already in reach, so a player
	standing in lane never stands still while aliens hit them.
]]
local function heroBrain(hero: Unit)
	-- Starting an attack would break a channel such as a recall.
	if hero.Order.Kind ~= "Idle" or hero.IsChanneling then
		return
	end

	local target = UnitServerService:FindNearest(
		hero.Position,
		hero.Stats.AttackRange + hero.Stats.Radius,
		function(other)
			return UnitServerService:CanAttack(hero, other)
		end
	)
	if target then
		UnitServerService:IssueOrder(hero, { Kind = "Attack", TargetId = target.Id })
	end
end

local function getSpawnPoint(team: Team): Vector3
	local fountain = fountains[team]
	return if fountain then fountain.Position else Vector3.zero
end

local function onUnitDied(unit: Unit)
	if unit.Kind ~= "Hero" then
		return
	end

	task.delay(RESPAWN_DELAY, function()
		if not unit.IsRemoved then
			UnitServerService:Revive(unit, getSpawnPoint(unit.Team))
		end
	end)
end

local function restoreAtFountains()
	for _, hero in heroes do
		if not hero or hero.IsDead then
			continue
		end
		local fountain = fountains[hero.Team]
		if fountain and (hero.Position - fountain.Position).Magnitude <= fountain.Radius then
			UnitServerService:Heal(hero, hero.Stats.MaxHealth * FOUNTAIN_RESTORE_SHARE)
			UnitServerService:RestoreResource(hero, hero.MaxResource * FOUNTAIN_RESTORE_SHARE)
		end
	end
end

function Module:RegisterHero(heroId: string, definition: HeroDefinition)
	definitions[heroId] = definition
end

--[[
	Sets where a team's heroes spawn and revive, and the radius (studs) in
	which the fountain restores them.
]]
function Module:SetFountain(team: Team, position: Vector3, radius: number)
	fountains[team] = {
		Position = position,
		Radius = radius,
	}
end

--[[
	Spawns the player's hero at its team's fountain, replacing any hero the
	player already has. Errors for a hero id that was never registered.
]]
function Module:SpawnHero(player: Player, heroId: string, team: Team): Unit
	local definition = definitions[heroId]
	if not definition then
		error(`No hero is registered as {heroId}`)
	end

	Module:RemoveHero(player)
	local hero = UnitServerService:SpawnUnit({
		Kind = "Hero",
		TypeId = heroId,
		Team = team,
		Stats = definition.Stats,
		Position = getSpawnPoint(team),
		OwnerPlayer = player,
		Brain = heroBrain,
		MaxResource = definition.MaxResource,
		RemoveOnDeath = false,
	})
	heroes[player] = hero
	Module.HeroSpawned:Fire(hero, heroId)
	return hero
end

function Module:RemoveHero(player: Player)
	local hero = heroes[player]
	if hero then
		heroes[player] = nil
		UnitServerService:RemoveUnit(hero)
		Module.HeroRemoved:Fire(hero)
	end
end

--[[
	Returns where a team's fountain stands, or nil when it has none.
]]
function Module:GetFountainPosition(team: Team): Vector3?
	local fountain = fountains[team]
	return if fountain then fountain.Position else nil
end

function Module:GetHero(player: Player): Unit?
	return heroes[player]
end

function Module:Init()
	UnitServerService.UnitDied:Connect(onUnitDied)
end

function Module:Start()
	task.spawn(function()
		while true do
			task.wait(FOUNTAIN_TICK)
			restoreAtFountains()
		end
	end)
end

return Module
