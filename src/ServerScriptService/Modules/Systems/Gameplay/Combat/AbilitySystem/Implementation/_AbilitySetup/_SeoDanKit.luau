--!strict

const RunService = game:GetService("RunService")

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const SEO_DAN_COLOR = Color3.fromRGB(150, 110, 255)
-- Seconds the flash of a cast stays on the screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
-- Radians of the cleave's arc, and how far past the hit area it is drawn.
const CLEAVE_ARC = 2.6
const CLEAVE_REACH = 1.4
const SOLDIER_TYPE_ID = "ShadowSoldier"
const KNIGHT_TYPE_ID = "ShadowKnight"
-- Soldiers keep pace with Seo Dan, whatever they were in life.
const SOLDIER_MOVE_SPEED = 16
const SOLDIER_ARMOR = 10
const SOLDIER_MAX_RADIUS = 2
-- A unit with no attack damage can't attack at all, so every soldier hits
-- for at least this much.
const SOLDIER_MIN_DAMAGE = 8
-- Studs within which a soldier picks a fight on its own.
const SOLDIER_SIGHT = 14
-- Studs from Seo Dan past which a soldier drops its fight and comes back.
const SOLDIER_LEASH = 22
-- Studs a soldier trails behind Seo Dan when there is nothing to fight.
const FOLLOW_DISTANCE = 5
const KNIGHT_STATS = {
	Armor = 20,
	AttackRange = 2.5,
	AttackInterval = 1.2,
	Radius = 1.4,
}
-- Seconds a fallen unit can still be raised, at most, and how many are
-- remembered.
const CORPSE_MEMORY_SECONDS = 20
const MAX_CORPSES = 30
-- Studs between soldiers charging one spot, so they don't stack.
const CHARGE_SPREAD = 2

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit
type UnitStats = UnitTypes.UnitStats

type Corpse = {
	Position: Vector3,
	Stats: UnitStats,
	-- SimClock time it fell.
	Time: number,
}

local soldiersByMaster: { [Unit]: { Unit }? } = {}
local corpses: { Corpse } = {}
local random = Random.new()

local function ring(position: Vector3, radius: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = SEO_DAN_COLOR,
		Duration = FLASH_DURATION,
	})
end

--[[
	Returns the master's soldiers still standing, oldest first.
]]
local function getSoldiers(master: Unit): { Unit }
	local standing = {}
	local known: { Unit } = soldiersByMaster[master] or {}
	for _, soldier in known do
		if not soldier.IsRemoved and not soldier.IsDead then
			table.insert(standing, soldier)
		end
	end
	soldiersByMaster[master] = standing
	return standing
end

local function moveTo(unit: Unit, point: Vector3)
	local order = unit.Order
	if order.Kind ~= "Move" or (order.Target - point).Magnitude > 1 then
		UnitServerService:IssueOrder(unit, { Kind = "Move", Target = point })
	end
end

local function attack(unit: Unit, target: Unit)
	local order = unit.Order
	if order.Kind ~= "Attack" or order.TargetId ~= target.Id then
		UnitServerService:IssueOrder(unit, { Kind = "Attack", TargetId = target.Id })
	end
end

--[[
	A soldier fights what its master fights, else the nearest enemy close
	by, and otherwise trails its master. It fades when its master dies.
]]
local function createSoldierBrain(master: Unit): (Unit) -> ()
	return function(soldier: Unit)
		if master.IsRemoved or master.IsDead then
			UnitServerService:RemoveUnit(soldier)
			return
		end

		local distanceToMaster = (soldier.Position - master.Position).Magnitude
		if distanceToMaster > SOLDIER_LEASH then
			moveTo(soldier, master.Position)
			return
		end

		local masterOrder = master.Order
		if masterOrder.Kind == "Attack" then
			local target = UnitServerService:GetUnit(masterOrder.TargetId)
			if target and UnitServerService:CanAttack(soldier, target) then
				attack(soldier, target)
				return
			end
		end
		local enemy = UnitServerService:FindNearest(soldier.Position, SOLDIER_SIGHT, function(other)
			return other.Kind ~= "Structure"
				and other.Kind ~= "Ward"
				and UnitServerService:CanAttack(soldier, other)
		end)
		if enemy then
			attack(soldier, enemy)
		elseif distanceToMaster > FOLLOW_DISTANCE then
			moveTo(soldier, master.Position)
		end
	end
end

local function spawnSoldier(
	master: Unit,
	typeId: string,
	stats: UnitStats,
	position: Vector3,
	seconds: number
): Unit
	local soldier = UnitServerService:SpawnUnit({
		Kind = "Summon",
		TypeId = typeId,
		Team = master.Team,
		Stats = stats,
		Position = position,
		Brain = createSoldierBrain(master),
	})
	local soldiers = getSoldiers(master)
	table.insert(soldiers, soldier)
	SimClock.delay(seconds, function()
		UnitServerService:RemoveUnit(soldier)
	end)
	ring(position, SMALL_RING_RADIUS)
	return soldier
end

local function onUnitDied(unit: Unit)
	if unit.Kind ~= "Minion" and unit.Kind ~= "Monster" then
		return
	end
	local now = SimClock.now()
	table.insert(corpses, {
		Position = unit.Position,
		Stats = unit.BaseStats,
		Time = now,
	})
	while
		#corpses > 0 and (#corpses > MAX_CORPSES or now - corpses[1].Time > CORPSE_MEMORY_SECONDS)
	do
		table.remove(corpses, 1)
	end
end

local function shadowSlash(context: CastContext): boolean
	local seoDan = context.Caster
	local values = context.Values
	local center = seoDan.Position + context.Direction * values.Radius * 0.6
	KitHelpers.damageAround(seoDan, center, values.Radius, values.Damage)
	AbilityServerService:PlayEffect({
		Kind = "Slash",
		Position = seoDan.Position,
		Direction = context.Direction,
		Radius = values.Radius * CLEAVE_REACH,
		Arc = CLEAVE_ARC,
		Color = SEO_DAN_COLOR,
		Duration = FLASH_DURATION,
	})
	return true
end

local function shadowRise(context: CastContext): boolean
	local seoDan = context.Caster
	local values = context.Values
	local now = SimClock.now()

	-- The newest fallen unit in reach rises first.
	local chosenIndex: number? = nil
	for index = #corpses, 1, -1 do
		local corpse = corpses[index]
		local isFresh = now - corpse.Time <= values.CorpseSeconds
		local isNear = (corpse.Position - seoDan.Position).Magnitude <= values.SearchRadius
		if isFresh and isNear then
			chosenIndex = index
			break
		end
	end
	if not chosenIndex then
		return false
	end
	local corpse = table.remove(corpses, chosenIndex) :: Corpse

	local soldiers = getSoldiers(seoDan)
	while #soldiers >= values.MaxSoldiers do
		UnitServerService:RemoveUnit(table.remove(soldiers, 1) :: Unit)
	end

	local base = corpse.Stats
	spawnSoldier(seoDan, SOLDIER_TYPE_ID, {
		MaxHealth = math.min(base.MaxHealth * values.HealthShare, values.HealthCap),
		Armor = SOLDIER_ARMOR,
		AttackDamage = math.clamp(
			base.AttackDamage * values.DamageShare,
			SOLDIER_MIN_DAMAGE,
			values.DamageCap
		),
		AttackRange = base.AttackRange,
		AttackInterval = base.AttackInterval,
		MoveSpeed = SOLDIER_MOVE_SPEED,
		Radius = math.min(base.Radius, SOLDIER_MAX_RADIUS),
		ProjectileSpeed = base.ProjectileSpeed,
	}, corpse.Position, values.Duration)
	return true
end

local function shadowSwap(context: CastContext): boolean
	local seoDan = context.Caster
	local nearest: Unit? = nil
	local nearestDistance = math.huge
	for _, soldier in getSoldiers(seoDan) do
		local distance = (soldier.Position - context.AimPoint).Magnitude
		if distance < nearestDistance then
			nearest = soldier
			nearestDistance = distance
		end
	end
	if not nearest then
		return false
	end

	local seoDanPosition = seoDan.Position
	UnitServerService:Teleport(seoDan, nearest.Position)
	UnitServerService:Teleport(nearest, seoDanPosition)
	ring(seoDanPosition, SMALL_RING_RADIUS)
	ring(seoDan.Position, SMALL_RING_RADIUS)
	return true
end

local function sovereignLegion(context: CastContext): boolean
	local seoDan = context.Caster
	local values = context.Values
	for index = 1, values.Knights do
		local angle = index / values.Knights * math.pi * 2
		local position = seoDan.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3
		spawnSoldier(seoDan, KNIGHT_TYPE_ID, {
			MaxHealth = values.KnightHealth,
			Armor = KNIGHT_STATS.Armor,
			AttackDamage = values.KnightDamage,
			AttackRange = KNIGHT_STATS.AttackRange,
			AttackInterval = KNIGHT_STATS.AttackInterval,
			MoveSpeed = SOLDIER_MOVE_SPEED,
			Radius = KNIGHT_STATS.Radius,
		}, position, values.KnightSeconds)
	end

	-- Each enemy takes the charge's damage once, however many soldiers land
	-- on it.
	local isHit: { [Unit]: boolean } = {}
	local aimPoint = context.AimPoint
	for _, soldier in getSoldiers(seoDan) do
		local spread = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
		local landing = aimPoint + spread * CHARGE_SPREAD
		UnitServerService:Dash(soldier, landing, values.ChargeSpeed, function(unit)
			for _, enemy in KitHelpers.findEnemiesAround(seoDan, unit.Position, values.ChargeRadius) do
				if isHit[enemy] then
					continue
				end
				isHit[enemy] = true
				UnitServerService:ApplyDamage(enemy, values.ChargeDamage, seoDan, "Ability")
				UnitServerService:AddModifier(enemy, "SeoDan.Legion.Slow", {
					Stat = "MoveSpeed",
					Multiply = values.SlowMultiplier,
				}, values.SlowSeconds)
			end
		end)
	end
	ring(aimPoint, values.ChargeRadius)
	return true
end

-- Specs and stories can load this module in edit mode, where nothing dies.
if RunService:IsRunning() then
	UnitServerService.UnitDied:Connect(onUnitDied)
end

local handlers: { [string]: AbilityHandler } = {
	["SeoDan.Q"] = shadowSlash,
	["SeoDan.W"] = shadowRise,
	["SeoDan.E"] = shadowSwap,
	["SeoDan.R"] = sovereignLegion,
}

return handlers
