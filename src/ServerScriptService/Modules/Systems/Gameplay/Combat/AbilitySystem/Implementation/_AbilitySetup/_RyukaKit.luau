--!strict

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const RYUKA_COLOR = Color3.fromRGB(250, 220, 60)
-- Seconds the flash of a cast stays on screen.
const FLASH_DURATION = 0.4
const BEAM_DURATION = 0.6
const SURGE_RING_RADIUS = 3
const CHARGE_RING_RADIUS = 2

const AbilityTypes = require("../../SystemPackage/AbilityTypes")

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext

local function kiVolley(context: CastContext): boolean
	local ryuka = context.Caster
	local values = context.Values
	AbilityServerService:FireSkillshot(ryuka, {
		Origin = ryuka.Position,
		Direction = context.Direction,
		Speed = values.Speed,
		Range = context.Info.Range,
		Width = values.Width,
		Color = RYUKA_COLOR,
		Filter = "EnemyUnit",
		OnHit = function(target)
			UnitServerService:ApplyDamage(target, values.Damage, ryuka, "Ability")
		end,
	})
	return true
end

local function powerSurge(context: CastContext): boolean
	local ryuka = context.Caster
	local values = context.Values
	UnitServerService:AddModifier(ryuka, "Ryuka.PowerSurge.AttackSpeed", {
		Stat = "AttackInterval",
		Multiply = values.AttackIntervalMultiplier,
	}, values.Duration)
	UnitServerService:AddModifier(ryuka, "Ryuka.PowerSurge.MoveSpeed", {
		Stat = "MoveSpeed",
		Multiply = values.MoveSpeedMultiplier,
	}, values.Duration)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = ryuka.Position,
		Radius = SURGE_RING_RADIUS,
		Color = RYUKA_COLOR,
		Duration = FLASH_DURATION,
	})
	return true
end

local function flashStep(context: CastContext): boolean
	UnitServerService:Dash(context.Caster, context.AimPoint, context.Values.DashSpeed)
	return true
end

local function celestialBeam(context: CastContext): boolean
	local ryuka = context.Caster
	local values = context.Values
	local direction = context.Direction
	local length = context.Info.Range

	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = ryuka.Position,
		Radius = CHARGE_RING_RADIUS,
		Color = RYUKA_COLOR,
		Duration = values.ChannelTime,
	})
	AbilityServerService:StartChannel(ryuka, {
		Name = context.Info.Name,
		Duration = values.ChannelTime,
		IsRooted = true,
		OnComplete = function()
			local origin = ryuka.Position
			KitHelpers.damageAlongLine(
				ryuka,
				origin,
				direction,
				length,
				values.Width,
				values.Damage
			)
			AbilityServerService:PlayEffect({
				Kind = "Beam",
				From = origin,
				To = origin + direction * length,
				Width = values.Width,
				Color = RYUKA_COLOR,
				Duration = BEAM_DURATION,
			})
		end,
	})
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Ryuka.Q"] = kiVolley,
	["Ryuka.W"] = powerSurge,
	["Ryuka.E"] = flashStep,
	["Ryuka.R"] = celestialBeam,
}

return handlers
