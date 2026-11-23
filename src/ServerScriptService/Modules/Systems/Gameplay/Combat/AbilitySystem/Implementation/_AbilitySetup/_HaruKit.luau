--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const HARU_COLOR = Color3.fromRGB(255, 150, 40)
-- Seconds the flash of a strike stays on screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
const BEAM_WIDTH = 0.6
-- Radians of a clone's strike, and between strikes' angles, so each storm
-- strike crosses the last from somewhere new.
const STRIKE_ARC = 2.2
const STRIKE_TURN = 2.1

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

-- The clone can't move, attack, or be attacked; it only marks a spot.
const CLONE_STATS: UnitTypes.UnitStats = {
	MaxHealth = 1,
	Armor = 0,
	AttackDamage = 0,
	AttackRange = 0,
	AttackInterval = 1,
	MoveSpeed = 0,
	Radius = 1.3,
}

local clones: { [Unit]: Unit? } = {}

local function getClone(haru: Unit): Unit?
	local clone = clones[haru]
	if clone and not clone.IsRemoved then
		return clone
	end
	clones[haru] = nil
	return nil
end

local function ring(position: Vector3, radius: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = HARU_COLOR,
		Duration = FLASH_DURATION,
	})
end

local function slash(position: Vector3, direction: Vector3, radius: number, arc: number)
	AbilityServerService:PlayEffect({
		Kind = "Slash",
		Position = position,
		Direction = direction,
		Radius = radius,
		Arc = arc,
		Color = HARU_COLOR,
		Duration = FLASH_DURATION,
	})
end

local function echoClone(context: CastContext): boolean
	local haru = context.Caster
	local values = context.Values
	local previous = getClone(haru)
	if previous then
		UnitServerService:RemoveUnit(previous)
	end

	local clone = UnitServerService:SpawnUnit({
		Kind = "Summon",
		TypeId = "HaruClone",
		Team = haru.Team,
		Stats = CLONE_STATS,
		Position = context.AimPoint,
		IsTargetable = false,
	})
	clones[haru] = clone
	ring(context.AimPoint, SMALL_RING_RADIUS)

	-- The clone strikes along with Haru's own attacks on enemies near it.
	local connection = UnitServerService.UnitDamaged:Connect(function(target, source, _dealt, kind)
		if source ~= haru or kind ~= "Attack" or clone.IsRemoved then
			return
		end
		if (target.Position - clone.Position).Magnitude > values.EchoRange then
			return
		end
		UnitServerService:ApplyDamage(target, values.EchoDamage, haru, "Ability")
		AbilityServerService:PlayEffect({
			Kind = "Beam",
			From = clone.Position,
			To = target.Position,
			Width = BEAM_WIDTH,
			Color = HARU_COLOR,
			Duration = FLASH_DURATION,
		})
	end)

	SimClock.delay(values.Duration, function()
		connection:Disconnect()
		if clones[haru] == clone then
			clones[haru] = nil
		end
		UnitServerService:RemoveUnit(clone)
	end)
	return true
end

local function spiralStrike(context: CastContext): boolean
	local values = context.Values
	UnitServerService:Dash(context.Caster, context.AimPoint, values.DashSpeed, function(haru)
		KitHelpers.damageAround(haru, haru.Position, values.Radius, values.Damage)
		ring(haru.Position, values.Radius)
		slash(haru.Position, context.Direction, values.Radius, math.pi * 2)
	end)
	return true
end

local function leafStep(context: CastContext): boolean
	local haru = context.Caster
	local clone = getClone(haru)
	if not clone then
		return false
	end

	local haruPosition = haru.Position
	UnitServerService:Teleport(haru, clone.Position)
	UnitServerService:Teleport(clone, haruPosition)
	ring(haruPosition, SMALL_RING_RADIUS)
	ring(haru.Position, SMALL_RING_RADIUS)
	return true
end

local function echoStorm(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local haru = context.Caster
	local values = context.Values
	for strike = 1, values.Strikes do
		SimClock.delay(values.StrikeInterval * strike, function()
			if target.IsDead or target.IsRemoved then
				return
			end
			UnitServerService:ApplyDamage(target, values.StrikeDamage, haru, "Ability")
			local angle = strike * STRIKE_TURN
			local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
			slash(target.Position, direction, values.RingRadius, STRIKE_ARC)
		end)
	end
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Haru.Q"] = echoClone,
	["Haru.W"] = spiralStrike,
	["Haru.E"] = leafStep,
	["Haru.R"] = echoStorm,
}

return handlers
