--!strict

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")
const KitHelpers = require("./_KitHelpers")

const BRAKK_COLOR = Color3.fromRGB(240, 150, 90)
-- Seconds the flash of a cast stays on the screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
-- Seconds between Colossus Form's slows, and how long each lasts, so the
-- slow holds while an enemy stays close and lets go soon after it leaves.
const AURA_INTERVAL = 0.5
const AURA_SLOW_SECONDS = 0.7

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

local function ring(position: Vector3, radius: number, duration: number?)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = BRAKK_COLOR,
		Duration = duration or FLASH_DURATION,
	})
end

local function slowAround(
	brakk: Unit,
	center: Vector3,
	radius: number,
	multiplier: number,
	seconds: number
)
	for _, enemy in KitHelpers.findEnemiesAround(brakk, center, radius) do
		UnitServerService:AddModifier(enemy, "Brakk.Slow", {
			Stat = "MoveSpeed",
			Multiply = multiplier,
		}, seconds)
	end
end

local function stoneFist(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end
	local values = context.Values
	UnitServerService:ApplyDamage(target, values.Damage, context.Caster, "Ability")
	UnitServerService:Stun(target, values.StunSeconds)
	ring(target.Position, SMALL_RING_RADIUS)
	return true
end

--[[
	Shields Brakk and the ally hero nearby with the smallest share of its
	health left.
]]
local function bulwark(context: CastContext): boolean
	local brakk = context.Caster
	local values = context.Values
	UnitServerService:AddShield(brakk, values.Shield, values.ShieldSeconds)
	ring(brakk.Position, SMALL_RING_RADIUS)

	local allies = UnitServerService:FindInRadius(brakk.Position, values.AllyRange, function(other)
		return other ~= brakk and other.Kind == "Hero" and other.Team == brakk.Team
	end)
	local weakest: Unit? = nil
	local weakestShare = math.huge
	for _, ally in allies do
		local share = ally.Health / math.max(ally.Stats.MaxHealth, 1)
		if share < weakestShare then
			weakest = ally
			weakestShare = share
		end
	end
	if weakest then
		UnitServerService:AddShield(weakest, values.Shield, values.ShieldSeconds)
		ring(weakest.Position, SMALL_RING_RADIUS)
	end
	return true
end

local function titanLeap(context: CastContext): boolean
	local values = context.Values
	UnitServerService:Dash(context.Caster, context.AimPoint, values.DashSpeed, function(brakk)
		KitHelpers.damageAround(brakk, brakk.Position, values.Radius, values.Damage)
		slowAround(brakk, brakk.Position, values.Radius, values.SlowMultiplier, values.SlowSeconds)
		ring(brakk.Position, values.Radius)
	end)
	return true
end

local function colossusForm(context: CastContext): boolean
	local brakk = context.Caster
	local values = context.Values
	local duration = values.Duration
	UnitServerService:SetEnlarged(brakk, true)
	UnitServerService:AddModifier(brakk, "Brakk.Colossus.Health", {
		Stat = "MaxHealth",
		Multiply = values.HealthMultiplier,
	}, duration)
	UnitServerService:AddModifier(brakk, "Brakk.Colossus.Armor", {
		Stat = "Armor",
		Add = values.ArmorBonus,
	}, duration)

	for _, enemy in KitHelpers.findEnemiesAround(brakk, brakk.Position, values.SlamRadius) do
		UnitServerService:ApplyDamage(enemy, values.SlamDamage, brakk, "Ability")
		UnitServerService:Stun(enemy, values.StunSeconds)
	end
	ring(brakk.Position, values.SlamRadius)
	ring(brakk.Position, values.AuraRadius, duration)

	task.spawn(function()
		local endsAt = os.clock() + duration
		while os.clock() < endsAt and not brakk.IsDead and not brakk.IsRemoved do
			slowAround(
				brakk,
				brakk.Position,
				values.AuraRadius,
				values.AuraSlowMultiplier,
				AURA_SLOW_SECONDS
			)
			task.wait(AURA_INTERVAL)
		end
		UnitServerService:SetEnlarged(brakk, false)
	end)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Brakk.Q"] = stoneFist,
	["Brakk.W"] = bulwark,
	["Brakk.E"] = titanLeap,
	["Brakk.R"] = colossusForm,
}

return handlers
