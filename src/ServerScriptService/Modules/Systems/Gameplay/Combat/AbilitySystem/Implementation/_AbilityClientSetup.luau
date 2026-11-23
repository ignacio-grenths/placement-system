--!strict

const UserInputService = game:GetService("UserInputService")

const GroundPlane = require("@game/ServerScriptService/Modules/Utilities/GroundPlane")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)
const UnitVisualsClientService = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/UnitVisualsSystem/SystemPackage/UnitVisualsClientService"
)

const AbilityClientService = require("../SystemPackage/AbilityClientService")
const AbilityRules = require("../SystemPackage/AbilityRules")

-- Studs around the aimed spot that a Unit ability still finds a target in,
-- so a cursor or drag just off a small alien still lands.
const TARGET_SEARCH_RADIUS = 6

const AbilityTypes = require("../SystemPackage/AbilityTypes")

type AbilityInfo = AbilityTypes.AbilityInfo
type Aim = AbilityTypes.Aim
type AimRequest = AbilityClientService.AimRequest
type ClientUnit = UnitClientService.ClientUnit
type TargetFilter = AbilityTypes.TargetFilter

local Module = {}

--[[
	Returns the unit passing the filter that is nearest to the spot and no
	more than maxFromSpot studs from it, among those within the ability's
	range of the hero.
]]
local function findTarget(
	hero: ClientUnit,
	heroPosition: Vector3,
	filter: TargetFilter,
	range: number,
	spot: Vector3,
	maxFromSpot: number
): ClientUnit?
	local renderTime = UnitClientService:GetRenderTime()
	local best: ClientUnit? = nil
	local bestDistance = math.huge
	for _, unit in UnitClientService:GetUnits() do
		if
			not unit
			or unit.IsDead
			or unit.IsHidden
			or not unit.IsTargetable
			or not AbilityRules.matchesFilter(hero.Team, unit.Team, unit.Kind, filter)
		then
			continue
		end
		local position = UnitClientService:GetRenderPose(unit, renderTime)
		local gap = (position - heroPosition).Magnitude - hero.Radius - unit.Radius
		local fromSpot = (position - spot).Magnitude
		if gap <= range and fromSpot <= maxFromSpot and fromSpot < bestDistance then
			best = unit
			bestDistance = fromSpot
		end
	end
	return best
end

local function resolveAim(info: AbilityInfo, request: AimRequest): Aim?
	local hero = UnitClientService:GetLocalHero()
	if not hero or hero.IsDead then
		return nil
	end
	local heroPosition, facing =
		UnitClientService:GetRenderPose(hero, UnitClientService:GetRenderTime())
	local facingDirection = Vector3.new(-math.sin(facing), 0, -math.cos(facing))
	if info.Targeting == "Self" then
		return { Point = heroPosition }
	end

	local spot = heroPosition + facingDirection * info.Range
	local searchRadius = TARGET_SEARCH_RADIUS
	local pointedUnit: ClientUnit? = nil
	if request.Kind == "Cursor" then
		local mouse = UserInputService:GetMouseLocation()
		local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
		pointedUnit = UnitVisualsClientService:PickUnit(ray)
		spot = GroundPlane.intersect(ray) or spot
	elseif request.Kind == "Toward" then
		spot = heroPosition + request.Direction * info.Range * math.clamp(request.Reach, 0, 1)
	else
		-- Auto aim fires at the nearest enemy, heroes first, in range.
		searchRadius = math.huge
		local enemy = findTarget(
			hero,
			heroPosition,
			"EnemyHero",
			info.Range,
			heroPosition,
			math.huge
		) or findTarget(hero, heroPosition, "EnemyUnit", info.Range, heroPosition, math.huge)
		if enemy then
			spot = UnitClientService:GetRenderPose(enemy, UnitClientService:GetRenderTime())
		end
	end

	if info.Targeting ~= "Unit" then
		return { Point = spot }
	end

	local filter: TargetFilter = info.TargetFilter or "EnemyUnit"
	if
		pointedUnit
		and AbilityRules.matchesFilter(hero.Team, pointedUnit.Team, pointedUnit.Kind, filter)
	then
		return { Point = spot, TargetId = pointedUnit.Id }
	end
	local target = findTarget(hero, heroPosition, filter, info.Range, spot, searchRadius)
	if not target then
		return nil
	end
	return { Point = spot, TargetId = target.Id }
end

function Module:Init()
	AbilityClientService:SetAimResolver(resolveAim)
end

return Module
