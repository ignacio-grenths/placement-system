--!strict

const AbilityRules = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityRules"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function isAbilityTarget(caster: Unit, other: Unit): boolean
	return other.IsTargetable
		and AbilityRules.matchesFilter(caster.Team, other.Team, other.Kind, "EnemyUnit")
end

--[[
	Returns every enemy unit (not structures) whose edge is within radius of
	the center.
]]
function Module.findEnemiesAround(caster: Unit, center: Vector3, radius: number): { Unit }
	return UnitServerService:FindInRadius(center, radius, function(other)
		return isAbilityTarget(caster, other)
	end)
end

--[[
	Deals ability damage to every enemy unit (not structures) whose edge is
	within radius of the center.
]]
function Module.damageAround(caster: Unit, center: Vector3, radius: number, damage: number)
	for _, target in Module.findEnemiesAround(caster, center, radius) do
		UnitServerService:ApplyDamage(target, damage, caster, "Ability")
	end
end

--[[
	Deals ability damage to every enemy unit (not structures) touching a band
	of the given width that runs length studs from origin along direction.
]]
function Module.damageAlongLine(
	caster: Unit,
	origin: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	damage: number
)
	local targets = {}
	for _, unit in UnitServerService:GetUnits() do
		if unit.IsRemoved or unit.IsDead or not isAbilityTarget(caster, unit) then
			continue
		end
		local offset = unit.Position - origin
		local along = offset:Dot(direction)
		local across = (offset - direction * along).Magnitude
		if along >= 0 and along <= length and across <= width / 2 + unit.Stats.Radius then
			table.insert(targets, unit)
		end
	end
	-- Damage after the scan, since a kill removes units from the live list.
	for _, target in targets do
		UnitServerService:ApplyDamage(target, damage, caster, "Ability")
	end
end

return Module
