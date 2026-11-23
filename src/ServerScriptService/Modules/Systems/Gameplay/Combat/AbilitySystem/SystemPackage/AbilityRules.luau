--!strict

const exhaustiveMatch = require("@game/ServerScriptService/Modules/Utilities/exhaustiveMatch")

const AbilityTypes = require("./AbilityTypes")

type ResourceProfile = AbilityTypes.ResourceProfile
type TargetFilter = AbilityTypes.TargetFilter

local Module = {}

--[[
	Returns a resource's new amount after dt seconds. Nothing comes back for
	a hero on cooldowns only, or until RegenDelay seconds have passed since
	the last spend.
]]
function Module.regenerate(
	profile: ResourceProfile,
	current: number,
	maximum: number,
	dt: number,
	secondsSinceSpend: number
): number
	if profile.Kind == "None" or secondsSinceSpend < profile.RegenDelay then
		return current
	end
	return math.min(current + profile.RegenPerSecond * dt, maximum)
end

--[[
	Returns what a cast costs this caster. A hero on cooldowns only pays
	nothing, whatever the ability lists.
]]
function Module.getCost(profile: ResourceProfile, listedCost: number): number
	return if profile.Kind == "None" then 0 else listedCost
end

--[[
	Returns whether a unit of targetTeam and targetKind is a valid target of
	the filter for a caster on casterTeam. Neutral monsters are enemies of
	both teams.
]]
function Module.matchesFilter(
	casterTeam: string,
	targetTeam: string,
	targetKind: string,
	filter: TargetFilter
): boolean
	local isEnemy = targetTeam ~= casterTeam
	if filter == "EnemyUnit" then
		return isEnemy and targetKind ~= "Structure" and targetKind ~= "Summon"
	elseif filter == "EnemyHero" then
		return isEnemy and targetKind == "Hero"
	elseif filter == "EnemyNonHero" then
		return isEnemy and (targetKind == "Minion" or targetKind == "Monster")
	elseif filter == "AllyUnit" then
		return not isEnemy and (targetKind == "Structure" or targetKind == "Minion")
	else
		return exhaustiveMatch(filter)
	end
end

--[[
	Pulls an aim point to within range of the caster and returns it with the
	flat direction toward it. Aiming at the caster's own spot uses
	fallbackDirection.
]]
function Module.clampAim(
	origin: Vector3,
	point: Vector3,
	range: number,
	fallbackDirection: Vector3
): (Vector3, Vector3)
	local offset = Vector3.new(point.X - origin.X, 0, point.Z - origin.Z)
	local distance = offset.Magnitude
	if distance < 0.01 then
		return origin, fallbackDirection
	end

	local direction = offset / distance
	return origin + direction * math.min(distance, range), direction
end

return Module
