--!strict

const AbilityServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityServerService"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const BotRoute = require("./BotRoute")

-- Share of max health below which a bot heads home, and the share it waits
-- for at the fountain before going back out.
const RETREAT_HEALTH_SHARE = 0.3
const RETURN_HEALTH_SHARE = 0.9
-- Studs within which a bot notices enemies around it.
const SIGHT_RANGE = 26
-- Studs from a lane's center line within which a unit counts as in it.
const LANE_WIDTH = 16
-- Studs a bot stays behind the front of its own wave.
const FOLLOW_DISTANCE = 6
-- Extra studs a bot keeps from an enemy tower no alien is tanking.
const TOWER_MARGIN = 4
-- Studs a bot steps back along its lane each time its spot is under a tower.
const TOWER_BACKOFF = 12
const MAX_BACKOFF_STEPS = 6
-- Studs to every enemy a bot needs before it starts a recall.
const RECALL_SAFE_DISTANCE = 28
-- A bot last-hits an alien left with less than this many of its attacks.
const LAST_HIT_ATTACKS = 1.1
-- Studs past its reach a bot will step to trade hits with a weaker hero.
const TRADE_LEEWAY = 4
-- Studs that count as already at a destination, so orders aren't reissued.
const ARRIVED_DISTANCE = 1.5
const ABILITY_SLOTS = { "R", "Q", "W", "E" }
const RECALL_SLOT = "B"

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Route = BotRoute.Route
type Slot = AbilityTypes.Slot
type Unit = UnitTypes.Unit

export type BotOptions = {
	-- Points from the bot's base to the enemy core along its lane.
	Lane: { Vector3 },
	Fountain: Vector3,
	FountainRadius: number,
}

local Module = {}

local function getHealthShare(unit: Unit): number
	return unit.Health / math.max(unit.Stats.MaxHealth, 1)
end

local function isLivingEnemy(bot: Unit, other: Unit): boolean
	return other.Team ~= bot.Team
		and not other.IsDead
		and not other.IsRemoved
		and other.IsTargetable
end

local function getReach(attacker: Unit, target: Unit): number
	return attacker.Stats.AttackRange + attacker.Stats.Radius + target.Stats.Radius
end

local function findThreateningTower(bot: Unit, point: Vector3): Unit?
	return UnitServerService:FindNearest(point, SIGHT_RANGE * 2, function(other)
		if other.Kind ~= "Structure" or other.Team == bot.Team or other.Stats.AttackDamage <= 0 then
			return false
		end
		local towerReach = other.Stats.AttackRange
			+ other.Stats.Radius
			+ bot.Stats.Radius
			+ TOWER_MARGIN
		return (other.Position - point).Magnitude <= towerReach
	end)
end

-- A tower shoots aliens before heroes, so a bot may fight under it while
-- one of its own aliens stands in range.
local function isTowerTanked(bot: Unit, tower: Unit): boolean
	local towerRange = tower.Stats.AttackRange + tower.Stats.Radius
	local tank = UnitServerService:FindNearest(tower.Position, towerRange, function(other)
		return other.Kind == "Minion" and other.Team == bot.Team
	end)
	return tank ~= nil
end

local function isSafeToReach(bot: Unit, point: Vector3, target: Unit?): boolean
	local tower = findThreateningTower(bot, point)
	return tower == nil or tower == target or isTowerTanked(bot, tower)
end

local function moveTo(bot: Unit, point: Vector3)
	local order = bot.Order
	if order.Kind == "Move" and (order.Target - point).Magnitude < ARRIVED_DISTANCE then
		return
	end
	if (bot.Position - point).Magnitude < ARRIVED_DISTANCE then
		return
	end
	UnitServerService:IssueOrder(bot, { Kind = "Move", Target = Vector3.new(point.X, 0, point.Z) })
end

local function attack(bot: Unit, target: Unit)
	local order = bot.Order
	if order.Kind == "Attack" and order.TargetId == target.Id then
		return
	end
	UnitServerService:IssueOrder(bot, { Kind = "Attack", TargetId = target.Id })
end

local function tryAbilities(bot: Unit, enemyHero: Unit)
	local gap = (enemyHero.Position - bot.Position).Magnitude
		- bot.Stats.Radius
		- enemyHero.Stats.Radius
	for _, slot in ABILITY_SLOTS do
		local info = AbilityServerService:GetAbilityInfo(bot, slot :: Slot)
		if not info then
			continue
		end
		-- Self abilities are buffs, worth using only once the fight is close.
		local isInRange = if info.Targeting == "Self"
			then gap <= bot.Stats.AttackRange + 2
			else gap <= info.Range
		if not isInRange then
			continue
		end
		local didCast = AbilityServerService:Cast(bot, slot :: Slot, {
			Point = enemyHero.Position,
			TargetId = enemyHero.Id,
		})
		if didCast then
			return
		end
	end
end

--[[
	Chooses what a laning bot hits: a last hit first, then a weaker enemy
	hero close by, then the nearest enemy alien, then a structure its own
	aliens are tanking. Nothing under an enemy tower that no alien tanks.
]]
local function pickTarget(bot: Unit, enemyHero: Unit?): Unit?
	local lastHit = UnitServerService:FindNearest(bot.Position, SIGHT_RANGE, function(other)
		return other.Kind == "Minion"
			and isLivingEnemy(bot, other)
			and other.Health <= bot.Stats.AttackDamage * LAST_HIT_ATTACKS
	end)
	if lastHit and isSafeToReach(bot, lastHit.Position, nil) then
		return lastHit
	end

	if
		enemyHero
		and getHealthShare(bot) > getHealthShare(enemyHero)
		and (enemyHero.Position - bot.Position).Magnitude <= getReach(bot, enemyHero) + TRADE_LEEWAY
		and isSafeToReach(bot, enemyHero.Position, nil)
	then
		return enemyHero
	end

	local minion = UnitServerService:FindNearest(bot.Position, SIGHT_RANGE, function(other)
		return other.Kind == "Minion" and isLivingEnemy(bot, other)
	end)
	if minion and isSafeToReach(bot, minion.Position, nil) then
		return minion
	end

	return UnitServerService:FindNearest(bot.Position, SIGHT_RANGE, function(other)
		return other.Kind == "Structure"
			and isLivingEnemy(bot, other)
			and (other.Stats.AttackDamage <= 0 or isTowerTanked(bot, other))
	end)
end

--[[
	Returns where a bot waits in its lane: just behind its own wave's front,
	or at its furthest standing tower when no wave is out, stepping back from
	any spot an untanked enemy tower covers.
]]
local function getLaneSpot(bot: Unit, route: Route): Vector3
	local frontProgress = -1
	for _, unit in UnitServerService:GetUnits() do
		local isAlliedWave = unit.Kind == "Minion" and unit.Team == bot.Team
		local isAlliedStructure = unit.Kind == "Structure" and unit.Team == bot.Team
		if unit.IsDead or unit.IsRemoved or not (isAlliedWave or isAlliedStructure) then
			continue
		end
		local progress, gap = BotRoute.project(route, unit.Position)
		if gap <= LANE_WIDTH and progress > frontProgress then
			frontProgress = progress
		end
	end

	local progress = math.max(frontProgress - FOLLOW_DISTANCE, 0)
	local spot = BotRoute.pointAt(route, progress)
	for _ = 1, MAX_BACKOFF_STEPS do
		if isSafeToReach(bot, spot, nil) then
			break
		end
		progress = math.max(progress - TOWER_BACKOFF, 0)
		spot = BotRoute.pointAt(route, progress)
	end
	return spot
end

--[[
	Returns a brain that plays a hero in one lane: it follows its wave,
	last-hits, trades with weaker heroes, casts abilities at enemy heroes,
	stays out of untanked enemy towers, and recalls home when low.
]]
function Module:CreateBrain(options: BotOptions): (Unit) -> ()
	local route = BotRoute.new(options.Lane)
	local isRetreating = false

	return function(bot: Unit)
		-- A channel (a recall, a charged beam) finishes on its own.
		if bot.IsChanneling then
			return
		end

		if isRetreating then
			local isAtFountain = (bot.Position - options.Fountain).Magnitude
				<= options.FountainRadius
			if not isAtFountain then
				local nearbyEnemy = UnitServerService:FindNearest(
					bot.Position,
					RECALL_SAFE_DISTANCE,
					function(other)
						return other.Kind ~= "Structure" and isLivingEnemy(bot, other)
					end
				)
				if not nearbyEnemy and AbilityServerService:Cast(bot, RECALL_SLOT :: Slot, nil) then
					return
				end
				moveTo(bot, options.Fountain)
				return
			end
			if getHealthShare(bot) < RETURN_HEALTH_SHARE then
				return
			end
			isRetreating = false
		elseif getHealthShare(bot) < RETREAT_HEALTH_SHARE then
			isRetreating = true
			moveTo(bot, options.Fountain)
			return
		end

		local enemyHero = UnitServerService:FindNearest(bot.Position, SIGHT_RANGE, function(other)
			return other.Kind == "Hero" and isLivingEnemy(bot, other)
		end)
		if enemyHero then
			tryAbilities(bot, enemyHero)
		end

		local target = pickTarget(bot, enemyHero)
		if target then
			attack(bot, target)
		else
			moveTo(bot, getLaneSpot(bot, route))
		end
	end
end

return Module
