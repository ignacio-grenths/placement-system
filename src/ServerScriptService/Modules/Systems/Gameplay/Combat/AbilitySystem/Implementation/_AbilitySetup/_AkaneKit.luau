--!strict

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const AKANE_COLOR = Color3.fromRGB(235, 60, 70)
-- Seconds the flash of a strike stays on screen.
const FLASH_DURATION = 0.4
const COMET_TRAIL_DURATION = 0.6
const THRUST_WIDTH = 1.2
const IMPACT_SLASH_RADIUS = 3
-- Radians.
const IMPACT_SLASH_ARC = 2.4

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

local function ring(position: Vector3, radius: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = AKANE_COLOR,
		Duration = FLASH_DURATION,
	})
end

local function beam(from: Vector3, to: Vector3, width: number, duration: number)
	AbilityServerService:PlayEffect({
		Kind = "Beam",
		From = from,
		To = to,
		Width = width,
		Color = AKANE_COLOR,
		Duration = duration,
	})
end

local function slash(position: Vector3, direction: Vector3, radius: number, arc: number)
	AbilityServerService:PlayEffect({
		Kind = "Slash",
		Position = position,
		Direction = direction,
		Radius = radius,
		Arc = arc,
		Color = AKANE_COLOR,
		Duration = FLASH_DURATION,
	})
end

local function slowAll(targets: { Unit }, key: string, multiplier: number, seconds: number)
	for _, target in targets do
		UnitServerService:AddModifier(target, key, {
			Stat = "MoveSpeed",
			Multiply = multiplier,
		}, seconds)
	end
end

local function piercingThrust(context: CastContext): boolean
	local akane = context.Caster
	local values = context.Values
	local origin = akane.Position
	local direction = context.Direction
	local length = context.Info.Range + akane.Stats.Radius
	local targets = KitHelpers.findEnemiesAlongLine(akane, origin, direction, length, values.Width)
	-- Slowed before the damage, since a kill removes the unit.
	slowAll(targets, "Akane.Thrust.Slow", values.SlowMultiplier, values.SlowSeconds)
	for _, target in targets do
		UnitServerService:ApplyDamage(target, values.Damage, akane, "Ability")
	end
	beam(origin, origin + direction * length, THRUST_WIDTH, FLASH_DURATION)
	return true
end

local function whirlwindGuard(context: CastContext): boolean
	local akane = context.Caster
	local values = context.Values
	KitHelpers.damageAround(akane, akane.Position, values.Radius, values.Damage)
	UnitServerService:AddShield(akane, values.Shield, values.ShieldSeconds, akane)
	slash(akane.Position, context.Direction, values.Radius, math.pi * 2)
	return true
end

local function poleVault(context: CastContext): boolean
	local values = context.Values
	UnitServerService:Dash(context.Caster, context.AimPoint, values.DashSpeed, function(akane)
		local enemies = KitHelpers.findEnemiesAround(akane, akane.Position, values.Radius)
		slowAll(enemies, "Akane.Vault.Slow", values.SlowMultiplier, values.SlowSeconds)
		ring(akane.Position, values.Radius)
	end)
	return true
end

--[[
	Charges the full range of the line, then strikes every enemy on the path
	she ran.
]]
local function crimsonComet(context: CastContext): boolean
	local akane = context.Caster
	local values = context.Values
	local origin = akane.Position
	local direction = context.Direction
	local length = context.Info.Range
	UnitServerService:Dash(akane, origin + direction * length, values.DashSpeed, function(unit)
		local reach = (unit.Position - origin).Magnitude + unit.Stats.Radius
		local struck = KitHelpers.findEnemiesAlongLine(unit, origin, direction, reach, values.Width)
		-- Stunned before the damage, since a kill removes the unit.
		for _, target in struck do
			UnitServerService:Stun(target, values.StunSeconds)
		end
		for _, target in struck do
			UnitServerService:ApplyDamage(target, values.Damage, unit, "Ability")
		end
		beam(origin, unit.Position, values.Width, COMET_TRAIL_DURATION)
		slash(unit.Position, direction, IMPACT_SLASH_RADIUS, IMPACT_SLASH_ARC)
	end)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Akane.Q"] = piercingThrust,
	["Akane.W"] = whirlwindGuard,
	["Akane.E"] = poleVault,
	["Akane.R"] = crimsonComet,
}

return handlers
