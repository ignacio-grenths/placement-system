--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)
const VisionServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/VisionSystem/SystemPackage/VisionServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const RIN_COLOR = Color3.fromRGB(110, 200, 255)
-- Seconds the flash of a strike stays on screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
const ZAP_WIDTH = 0.5
const BOLT_WIDTH = 2.5
-- Studs above the strike that a lightning bolt falls from.
const BOLT_HEIGHT = 40
-- Seconds between Fox Fire's burns.
const FOX_FIRE_INTERVAL = 1

const AbilityTypes = require("../../SystemPackage/AbilityTypes")

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext

local function ring(position: Vector3, radius: number, duration: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = RIN_COLOR,
		Duration = duration,
	})
end

local function beam(from: Vector3, to: Vector3, width: number)
	AbilityServerService:PlayEffect({
		Kind = "Beam",
		From = from,
		To = to,
		Width = width,
		Color = RIN_COLOR,
		Duration = FLASH_DURATION,
	})
end

local function lightningLunge(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local rin = context.Caster
	local values = context.Values
	local start = rin.Position
	-- She lands beside the target, on the side she came from.
	local offset = start - target.Position
	local away = if offset.Magnitude > 0.01 then offset.Unit else Vector3.zAxis
	local landing = target.Position + away * (target.Stats.Radius + rin.Stats.Radius)
	UnitServerService:Dash(rin, landing, values.DashSpeed, function(unit)
		if target.IsDead or target.IsRemoved then
			return
		end
		UnitServerService:ApplyDamage(target, values.Damage, unit, "Ability")
		beam(start, target.Position, ZAP_WIDTH)
		ring(target.Position, SMALL_RING_RADIUS, FLASH_DURATION)
		UnitServerService:IssueOrder(unit, { Kind = "Attack", TargetId = target.Id })
	end)
	return true
end

local function foxFire(context: CastContext): boolean
	local rin = context.Caster
	local values = context.Values
	local duration = values.Ticks * FOX_FIRE_INTERVAL
	UnitServerService:AddModifier(rin, "Rin.FoxFire.Speed", {
		Stat = "MoveSpeed",
		Multiply = values.MoveSpeedMultiplier,
	}, duration)
	task.spawn(function()
		for _ = 1, values.Ticks do
			if rin.IsDead or rin.IsRemoved then
				return
			end
			KitHelpers.damageAround(rin, rin.Position, values.Radius, values.TickDamage)
			ring(rin.Position, values.Radius, FLASH_DURATION)
			SimClock.wait(FOX_FIRE_INTERVAL)
		end
	end)
	return true
end

local function staticMark(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local rin = context.Caster
	local values = context.Values
	VisionServerService:Reveal(target, rin.Team, values.RevealSeconds)
	UnitServerService:AddModifier(target, "Rin.StaticMark.Slow", {
		Stat = "MoveSpeed",
		Multiply = values.SlowMultiplier,
	}, values.SlowSeconds)
	UnitServerService:ApplyDamage(target, values.Damage, rin, "Ability")
	beam(rin.Position, target.Position, ZAP_WIDTH)
	return true
end

--[[
	Marks the area at once, so enemies see the strike coming and can run.
]]
local function thunderFall(context: CastContext): boolean
	local rin = context.Caster
	local values = context.Values
	local center = context.AimPoint
	ring(center, values.Radius, values.Delay)
	SimClock.delay(values.Delay, function()
		local struck = KitHelpers.findEnemiesAround(rin, center, values.Radius)
		-- Stunned before the damage, since a kill removes the unit.
		for _, target in struck do
			UnitServerService:Stun(target, values.StunSeconds)
		end
		for _, target in struck do
			UnitServerService:ApplyDamage(target, values.Damage, rin, "Ability")
		end
		beam(center + Vector3.new(0, BOLT_HEIGHT, 0), center, BOLT_WIDTH)
		ring(center, values.Radius, FLASH_DURATION)
	end)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Rin.Q"] = lightningLunge,
	["Rin.W"] = foxFire,
	["Rin.E"] = staticMark,
	["Rin.R"] = thunderFall,
}

return handlers
