--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")

const TORVIK_COLOR = Color3.fromRGB(230, 170, 110)
-- Seconds the flash of a strike stays on the screen.
const FLASH_DURATION = 0.4
const SMALL_RING_RADIUS = 2.5
const CAST_RING_RADIUS = 3
const BEAM_WIDTH = 0.6

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Connection = Signal.Connection
type Unit = UnitTypes.Unit

local function ring(position: Vector3, radius: number, duration: number?)
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = position,
		Radius = radius,
		Color = TORVIK_COLOR,
		Duration = duration or FLASH_DURATION,
	})
end

local function slow(target: Unit, key: string, multiplier: number, seconds: number)
	UnitServerService:AddModifier(target, key, {
		Stat = "MoveSpeed",
		Multiply = multiplier,
	}, seconds)
end

local function twinFangs(context: CastContext): boolean
	local torvik = context.Caster
	local values = context.Values
	UnitServerService:AddModifier(torvik, "Torvik.TwinFangs", {
		Stat = "AttackInterval",
		Multiply = values.AttackIntervalMultiplier,
	}, values.Duration)

	local hitsLeft = values.Hits
	local connection: Connection? = nil
	local function finish()
		local current = connection
		if current then
			current:Disconnect()
		end
		UnitServerService:RemoveModifier(torvik, "Torvik.TwinFangs")
	end
	connection = UnitServerService.UnitDamaged:Connect(function(target, source, _dealt, kind)
		if source ~= torvik or kind ~= "Attack" or hitsLeft <= 0 then
			return
		end
		hitsLeft -= 1
		UnitServerService:ApplyDamage(target, values.BonusDamage, torvik, "Ability")
		ring(target.Position, SMALL_RING_RADIUS)
		if hitsLeft == 0 then
			slow(target, "Torvik.TwinFangs.Slow", values.SlowMultiplier, values.SlowSeconds)
			finish()
		end
	end)
	task.delay(values.Duration, finish)
	ring(torvik.Position, CAST_RING_RADIUS)
	return true
end

local function parry(context: CastContext): boolean
	local torvik = context.Caster
	local values = context.Values
	UnitServerService:BlockHits(torvik, 1, values.Window)

	local connection: Connection? = nil
	local function finish()
		local current = connection
		if current then
			current:Disconnect()
		end
	end
	connection = UnitServerService.HitBlocked:Connect(function(unit, source)
		if unit ~= torvik then
			return
		end
		finish()
		-- The counter answers heroes, aliens, and monsters, never a tower.
		if
			not source
			or source.IsDead
			or source.IsRemoved
			or source.Kind == "Structure"
			or source.Team == torvik.Team
		then
			return
		end
		UnitServerService:ApplyDamage(source, values.CounterDamage, torvik, "Ability")
		UnitServerService:Stun(source, values.StunSeconds)
		AbilityServerService:PlayEffect({
			Kind = "Beam",
			From = torvik.Position,
			To = source.Position,
			Width = BEAM_WIDTH,
			Color = TORVIK_COLOR,
			Duration = FLASH_DURATION,
		})
	end)
	task.delay(values.Window, finish)
	ring(torvik.Position, SMALL_RING_RADIUS, values.Window)
	return true
end

local function leapStrike(context: CastContext): boolean
	local target = context.Target
	if not target then
		return false
	end

	local torvik = context.Caster
	local values = context.Values
	-- He lands beside the target, not on top of it.
	local offset = torvik.Position - target.Position
	local away = if offset.Magnitude > 0.01 then offset.Unit else Vector3.zAxis
	local landing = target.Position + away * (target.Stats.Radius + torvik.Stats.Radius)
	UnitServerService:Dash(torvik, landing, values.DashSpeed, function(unit)
		if target.IsDead or target.IsRemoved then
			return
		end
		UnitServerService:ApplyDamage(target, values.Damage, unit, "Ability")
		slow(target, "Torvik.LeapStrike.Slow", values.SlowMultiplier, values.SlowSeconds)
		ring(target.Position, SMALL_RING_RADIUS)
		UnitServerService:IssueOrder(unit, { Kind = "Attack", TargetId = target.Id })
	end)
	return true
end

local function berserkFlurry(context: CastContext): boolean
	local torvik = context.Caster
	local values = context.Values
	UnitServerService:AddModifier(torvik, "Torvik.Berserk.AttackSpeed", {
		Stat = "AttackInterval",
		Multiply = values.AttackIntervalMultiplier,
	}, values.Duration)
	UnitServerService:AddModifier(torvik, "Torvik.Berserk.MoveSpeed", {
		Stat = "MoveSpeed",
		Multiply = values.MoveSpeedMultiplier,
	}, values.Duration)

	local endsAt = os.clock() + values.Duration
	local connection = UnitServerService.UnitDamaged:Connect(function(target, source, dealt)
		if source == torvik and target.Team ~= torvik.Team and os.clock() < endsAt then
			UnitServerService:Heal(torvik, dealt * values.Lifesteal)
		end
	end)
	task.delay(values.Duration, function()
		connection:Disconnect()
	end)
	ring(torvik.Position, CAST_RING_RADIUS, values.Duration)
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Torvik.Q"] = twinFangs,
	["Torvik.W"] = parry,
	["Torvik.E"] = leapStrike,
	["Torvik.R"] = berserkFlurry,
}

return handlers
