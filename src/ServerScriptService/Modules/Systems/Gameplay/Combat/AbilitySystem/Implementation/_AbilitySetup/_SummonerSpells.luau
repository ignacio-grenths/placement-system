--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")

const SPELL_COLOR = Color3.fromRGB(170, 230, 255)
const HARMFUL_COLOR = Color3.fromRGB(255, 120, 60)
-- Seconds the flash of a spell stays on screen.
const FLASH_DURATION = 0.4
const RING_RADIUS = 3
const BEAM_WIDTH = 0.6

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

local function ring(position: Vector3, color: Color3)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = RING_RADIUS,
		Color = color,
		Duration = FLASH_DURATION,
	})
end

local function beam(from: Vector3, to: Vector3, color: Color3)
	AbilityServerService:PlayEffect({
		Kind = "Beam",
		From = from,
		To = to,
		Width = BEAM_WIDTH,
		Color = color,
		Duration = FLASH_DURATION,
	})
end

local function blink(context: CastContext): boolean
	local caster = context.Caster
	ring(caster.Position, SPELL_COLOR)
	UnitServerService:Teleport(caster, context.AimPoint)
	ring(context.AimPoint, SPELL_COLOR)
	return true
end

local function mend(context: CastContext): boolean
	local caster = context.Caster
	local values = context.Values
	UnitServerService:Heal(caster, caster.Stats.MaxHealth * values.HealShare)

	-- The ally missing the largest share of health gets the same heal.
	local allies = UnitServerService:FindInRadius(caster.Position, values.AllyRange, function(other)
		return other ~= caster and other.Kind == "Hero" and other.Team == caster.Team
	end)
	local mostHurt: Unit? = nil
	for _, ally in allies do
		if
			not mostHurt
			or ally.Health / ally.Stats.MaxHealth < mostHurt.Health / mostHurt.Stats.MaxHealth
		then
			mostHurt = ally
		end
	end
	if mostHurt then
		UnitServerService:Heal(mostHurt, mostHurt.Stats.MaxHealth * values.HealShare)
		ring(mostHurt.Position, SPELL_COLOR)
	end

	UnitServerService:AddModifier(caster, "Spell.Mend.Speed", {
		Stat = "MoveSpeed",
		Multiply = values.SpeedMultiplier,
	}, values.SpeedDuration)
	ring(caster.Position, SPELL_COLOR)
	return true
end

local function scorch(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local caster = context.Caster
	local values = context.Values
	UnitServerService:CutHealing(target, values.Duration)
	beam(caster.Position, target.Position, HARMFUL_COLOR)
	task.spawn(function()
		for _ = 1, values.Duration do
			SimClock.wait(1)
			if target.IsDead or target.IsRemoved then
				return
			end
			UnitServerService:ApplyDamage(target, values.DamagePerSecond, caster, "Ability")
		end
	end)
	return true
end

local function hunt(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end
	UnitServerService:ApplyDamage(target, context.Values.Damage, context.Caster, "True")
	beam(context.Caster.Position, target.Position, SPELL_COLOR)
	return true
end

local function warp(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local caster = context.Caster
	local values = context.Values
	ring(caster.Position, SPELL_COLOR)
	AbilityServerService:StartChannel(caster, {
		Name = context.Info.Name,
		Duration = values.ChannelTime,
		CancelOnOrder = true,
		OnComplete = function()
			if target.IsDead or target.IsRemoved or caster.IsDead then
				return
			end
			-- Lands beside the target, on the side the caster came from.
			local away = caster.Position - target.Position
			local side = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
			local landing = target.Position + side * (target.Stats.Radius + values.LandingOffset)
			UnitServerService:Teleport(caster, landing)
			ring(landing, SPELL_COLOR)
		end,
	})
	return true
end

local function drain(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local values = context.Values
	UnitServerService:AddModifier(target, "Spell.Drain.Slow", {
		Stat = "MoveSpeed",
		Multiply = values.SlowMultiplier,
	}, values.Duration)
	UnitServerService:AddModifier(target, "Spell.Drain.Damage", {
		Stat = "AttackDamage",
		Multiply = values.DamageMultiplier,
	}, values.Duration)
	beam(context.Caster.Position, target.Position, HARMFUL_COLOR)
	return true
end

local function purify(context: CastContext): boolean
	local caster = context.Caster
	UnitServerService:ClearImpairments(caster)
	UnitServerService:GrantCrowdControlImmunity(caster, context.Values.ImmunityDuration)
	ring(caster.Position, SPELL_COLOR)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Spell.Blink"] = blink,
	["Spell.Mend"] = mend,
	["Spell.Scorch"] = scorch,
	["Spell.Hunt"] = hunt,
	["Spell.Warp"] = warp,
	["Spell.Drain"] = drain,
	["Spell.Purify"] = purify,
}

return handlers
