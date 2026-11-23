--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const MIO_COLOR = Color3.fromRGB(255, 120, 130)
const HOLY_COLOR = Color3.fromRGB(255, 236, 170)
-- Seconds the flash of a cast stays on screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
-- Seconds between pulses of a lasting area.
const PULSE_INTERVAL = 0.5
-- A pulse's slow outlasts the gap to the next pulse, so it never flickers.
const SLOW_OVERLAP = 0.2

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

local function ring(position: Vector3, radius: number, color: Color3, duration: number)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = color,
		Duration = duration,
	})
end

local function findAlliedHeroes(mio: Unit, center: Vector3, radius: number): { Unit }
	return UnitServerService:FindInRadius(center, radius, function(other)
		return other.Kind == "Hero" and other.Team == mio.Team
	end)
end

local function bindingTalisman(context: CastContext): boolean
	local mio = context.Caster
	local values = context.Values
	AbilityServerService:FireSkillshot(mio, {
		Origin = mio.Position,
		Direction = context.Direction,
		Speed = values.Speed,
		Range = context.Info.Range,
		Width = values.Width,
		Color = MIO_COLOR,
		Filter = "EnemyUnit",
		OnHit = function(target)
			-- Stunned before the damage, since a kill removes the unit.
			UnitServerService:Stun(target, values.StunSeconds)
			UnitServerService:ApplyDamage(target, values.Damage, mio, "Ability")
			ring(target.Position, SMALL_RING_RADIUS, MIO_COLOR, FLASH_DURATION)
		end,
	})
	return true
end

--[[
	Heals Mio and the ally hero nearby with the smallest share of its health
	left, and speeds both up.
]]
local function blessing(context: CastContext): boolean
	local mio = context.Caster
	local values = context.Values
	local blessed = { mio }
	local mostHurt: Unit? = nil
	local mostHurtShare = math.huge
	for _, ally in findAlliedHeroes(mio, mio.Position, values.AllyRange) do
		local share = ally.Health / math.max(ally.Stats.MaxHealth, 1)
		if ally ~= mio and share < mostHurtShare then
			mostHurt = ally
			mostHurtShare = share
		end
	end
	if mostHurt then
		table.insert(blessed, mostHurt)
	end

	for _, hero in blessed do
		UnitServerService:Heal(hero, values.Heal)
		UnitServerService:AddModifier(hero, "Mio.Blessing.Speed", {
			Stat = "MoveSpeed",
			Multiply = values.MoveSpeedMultiplier,
		}, values.SpeedSeconds)
		ring(hero.Position, SMALL_RING_RADIUS, HOLY_COLOR, FLASH_DURATION)
	end
	return true
end

local function purifyingBarrier(context: CastContext): boolean
	local mio = context.Caster
	local values = context.Values
	local center = context.AimPoint
	ring(center, values.Radius, MIO_COLOR, values.Duration)
	task.spawn(function()
		local endsAt = SimClock.now() + values.Duration
		while SimClock.now() < endsAt do
			for _, enemy in KitHelpers.findEnemiesAround(mio, center, values.Radius) do
				UnitServerService:AddModifier(enemy, "Mio.Barrier.Slow", {
					Stat = "MoveSpeed",
					Multiply = values.SlowMultiplier,
				}, PULSE_INTERVAL + SLOW_OVERLAP)
			end
			SimClock.wait(PULSE_INTERVAL)
		end
	end)
	return true
end

--[[
	The ground stays where she cast it, so allies have to stand in it to be
	healed.
]]
local function sacredGround(context: CastContext): boolean
	local mio = context.Caster
	local values = context.Values
	local center = mio.Position
	ring(center, values.Radius, HOLY_COLOR, values.Duration)
	task.spawn(function()
		local endsAt = SimClock.now() + values.Duration
		while SimClock.now() < endsAt do
			for _, ally in findAlliedHeroes(mio, center, values.Radius) do
				UnitServerService:Heal(ally, values.HealPerTick)
			end
			for _, enemy in KitHelpers.findEnemiesAround(mio, center, values.Radius) do
				UnitServerService:ApplyDamage(enemy, values.DamagePerTick, mio, "Ability")
			end
			SimClock.wait(PULSE_INTERVAL)
		end
	end)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Mio.Q"] = bindingTalisman,
	["Mio.W"] = blessing,
	["Mio.E"] = purifyingBarrier,
	["Mio.R"] = sacredGround,
}

return handlers
