--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const YUKI_COLOR = Color3.fromRGB(150, 215, 255)
-- Seconds the flash of a cast stays on screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
-- Each blizzard tick flashes at a spot within this share of its radius.
const FLURRY_SPREAD = 0.6
const FLURRY_RADIUS = 2

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

local random = Random.new()

local function ring(position: Vector3, radius: number, duration: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = YUKI_COLOR,
		Duration = duration,
	})
end

local function chill(target: Unit, key: string, multiplier: number, seconds: number)
	UnitServerService:AddModifier(target, key, {
		Stat = "MoveSpeed",
		Multiply = multiplier,
	}, seconds)
end

local function iceLance(context: CastContext): boolean
	local yuki = context.Caster
	local values = context.Values
	AbilityServerService:FireSkillshot(yuki, {
		Origin = yuki.Position,
		Direction = context.Direction,
		Speed = values.Speed,
		Range = context.Info.Range,
		Width = values.Width,
		Color = YUKI_COLOR,
		Filter = "EnemyUnit",
		OnHit = function(target)
			-- Slowed before the damage, since a kill removes the unit.
			chill(target, "Yuki.IceLance.Slow", values.SlowMultiplier, values.SlowSeconds)
			UnitServerService:ApplyDamage(target, values.Damage, yuki, "Ability")
		end,
	})
	return true
end

--[[
	Marks the area at once, so enemies see the freeze coming and can step
	out.
]]
local function frostField(context: CastContext): boolean
	local yuki = context.Caster
	local values = context.Values
	local center = context.AimPoint
	ring(center, values.Radius, values.Delay)
	SimClock.delay(values.Delay, function()
		local frozen = KitHelpers.findEnemiesAround(yuki, center, values.Radius)
		for _, target in frozen do
			UnitServerService:Root(target, values.RootSeconds)
		end
		for _, target in frozen do
			UnitServerService:ApplyDamage(target, values.Damage, yuki, "Ability")
		end
		ring(center, values.Radius, FLASH_DURATION)
	end)
	return true
end

local function iceBarrier(context: CastContext): boolean
	local yuki = context.Caster
	local values = context.Values
	UnitServerService:AddShield(yuki, values.Shield, values.ShieldSeconds, yuki)
	for _, enemy in KitHelpers.findEnemiesAround(yuki, yuki.Position, values.Radius) do
		chill(enemy, "Yuki.IceBarrier.Slow", values.SlowMultiplier, values.SlowSeconds)
	end
	ring(yuki.Position, SMALL_RING_RADIUS, FLASH_DURATION)
	ring(yuki.Position, values.Radius, FLASH_DURATION)
	return true
end

--[[
	The storm ticks for as long as the channel holds, so a stun or another
	cast ends it early.
]]
local function blizzard(context: CastContext): boolean
	local yuki = context.Caster
	local values = context.Values
	local center = context.AimPoint
	local interval = values.ChannelTime / values.Ticks
	ring(center, values.Radius, values.ChannelTime)
	AbilityServerService:StartChannel(yuki, {
		Name = context.Info.Name,
		Duration = values.ChannelTime,
		IsRooted = true,
		OnComplete = function() end,
	})
	task.spawn(function()
		for _ = 1, values.Ticks do
			SimClock.wait(interval)
			if not yuki.IsChanneling or yuki.IsDead then
				return
			end
			for _, enemy in KitHelpers.findEnemiesAround(yuki, center, values.Radius) do
				chill(enemy, "Yuki.Blizzard.Slow", values.SlowMultiplier, values.SlowSeconds)
				UnitServerService:ApplyDamage(enemy, values.TickDamage, yuki, "Ability")
			end
			local angle = random:NextNumber(0, math.pi * 2)
			local spread = random:NextNumber(0, values.Radius * FLURRY_SPREAD)
			local flurry = center + Vector3.new(math.sin(angle), 0, math.cos(angle)) * spread
			ring(flurry, FLURRY_RADIUS, FLASH_DURATION)
		end
	end)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Yuki.Q"] = iceLance,
	["Yuki.W"] = frostField,
	["Yuki.E"] = iceBarrier,
	["Yuki.R"] = blizzard,
}

return handlers
