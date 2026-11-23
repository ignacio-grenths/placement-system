--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const KENJI_COLOR = Color3.fromRGB(255, 196, 90)
-- Seconds the flash of a shot stays on screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
const TRACER_WIDTH = 0.4
const FINAL_BULLET_WIDTH = 1.4
const GRENADE_WIDTH = 0.8

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Connection = Signal.Connection
type Unit = UnitTypes.Unit

local function ring(position: Vector3, radius: number, duration: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = KENJI_COLOR,
		Duration = duration,
	})
end

local function tracer(from: Vector3, to: Vector3, width: number)
	AbilityServerService:PlayEffect({
		Kind = "Beam",
		From = from,
		To = to,
		Width = width,
		Color = KENJI_COLOR,
		Duration = FLASH_DURATION,
	})
end

--[[
	Hits the first enemy in the bullet's path, then bounces for part of the
	damage to the nearest other enemy close to it.
]]
local function ricochetShot(context: CastContext): boolean
	local kenji = context.Caster
	local values = context.Values
	AbilityServerService:FireSkillshot(kenji, {
		Origin = kenji.Position,
		Direction = context.Direction,
		Speed = values.Speed,
		Range = context.Info.Range,
		Width = values.Width,
		Color = KENJI_COLOR,
		Filter = "EnemyUnit",
		OnHit = function(target)
			local bounceFrom = target.Position
			local bounceTo = UnitServerService:FindNearest(
				bounceFrom,
				values.BounceRange,
				function(other)
					return other ~= target and KitHelpers.isAbilityTarget(kenji, other)
				end
			)
			UnitServerService:ApplyDamage(target, values.Damage, kenji, "Ability")
			if bounceTo then
				local bounceDamage = values.Damage * values.BounceShare
				UnitServerService:ApplyDamage(bounceTo, bounceDamage, kenji, "Ability")
				tracer(bounceFrom, bounceTo.Position, TRACER_WIDTH)
			end
		end,
	})
	return true
end

local function smokeRoll(context: CastContext): boolean
	local kenji = context.Caster
	local values = context.Values
	local start = kenji.Position
	UnitServerService:Dash(kenji, context.AimPoint, values.DashSpeed)
	ring(start, SMALL_RING_RADIUS, FLASH_DURATION)

	local hitsLeft = values.Hits
	local connection: Connection? = nil
	local function finish()
		local current = connection
		if current then
			current:Disconnect()
		end
	end
	connection = UnitServerService.UnitDamaged:Connect(function(target, source, _dealt, kind)
		if source ~= kenji or kind ~= "Attack" or hitsLeft <= 0 then
			return
		end
		hitsLeft -= 1
		UnitServerService:ApplyDamage(target, values.BonusDamage, kenji, "Ability")
		ring(target.Position, SMALL_RING_RADIUS, FLASH_DURATION)
		if hitsLeft == 0 then
			finish()
		end
	end)
	SimClock.delay(values.Window, finish)
	return true
end

--[[
	The grenade is drawn arcing to the spot, landing as it goes off.
]]
local function flashGrenade(context: CastContext): boolean
	local kenji = context.Caster
	local values = context.Values
	local center = context.AimPoint
	local offset = center - kenji.Position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if distance > 0.1 then
		AbilityServerService:PlayEffect({
			Kind = "Projectile",
			Origin = kenji.Position,
			Direction = Vector3.new(offset.X, 0, offset.Z).Unit,
			Speed = distance / values.Delay,
			Range = distance,
			Width = GRENADE_WIDTH,
			Color = KENJI_COLOR,
		})
	end
	SimClock.delay(values.Delay, function()
		local caught = KitHelpers.findEnemiesAround(kenji, center, values.Radius)
		-- Slowed before the damage, since a kill removes the unit.
		for _, target in caught do
			UnitServerService:AddModifier(target, "Kenji.Grenade.Slow", {
				Stat = "MoveSpeed",
				Multiply = values.SlowMultiplier,
			}, values.SlowSeconds)
		end
		for _, target in caught do
			UnitServerService:ApplyDamage(target, values.Damage, kenji, "Ability")
		end
		ring(center, values.Radius, FLASH_DURATION)
	end)
	return true
end

--[[
	Kenji stands still to aim, and the shot is lost if he is stunned or the
	target escapes out of reach before it fires.
]]
local function finalBullet(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local kenji = context.Caster
	local values = context.Values
	local reach = context.Info.Range + kenji.Stats.Radius + target.Stats.Radius
	ring(kenji.Position, SMALL_RING_RADIUS, values.AimTime)
	AbilityServerService:StartChannel(kenji, {
		Name = context.Info.Name,
		Duration = values.AimTime,
		IsRooted = true,
		OnComplete = function()
			if target.IsDead or target.IsRemoved or kenji.IsDead then
				return
			end
			if (target.Position - kenji.Position).Magnitude > reach then
				return
			end
			local missing = math.max(target.Stats.MaxHealth - target.Health, 0)
			local damage = values.Damage + missing * values.MissingHealthShare
			tracer(kenji.Position, target.Position, FINAL_BULLET_WIDTH)
			UnitServerService:ApplyDamage(target, damage, kenji, "Ability")
		end,
	})
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Kenji.Q"] = ricochetShot,
	["Kenji.W"] = smokeRoll,
	["Kenji.E"] = flashGrenade,
	["Kenji.R"] = finalBullet,
}

return handlers
