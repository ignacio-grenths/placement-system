--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")

const WARD_TYPE_ID = "SensorWard"
const WARD_COLOR = Color3.fromRGB(255, 220, 90)
-- Seconds the flash of a placement stays on screen.
const FLASH_DURATION = 0.4
const RING_RADIUS = 2

const AbilityTypes = require("../../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext
type Unit = UnitTypes.Unit

local wardsByOwner: { [Unit]: { Unit }? } = {}

--[[
	Returns the owner's wards still standing, oldest first.
]]
local function getWards(owner: Unit): { Unit }
	local standing = {}
	local known: { Unit } = wardsByOwner[owner] or {}
	for _, ward in known do
		if not ward.IsRemoved and not ward.IsDead then
			table.insert(standing, ward)
		end
	end
	wardsByOwner[owner] = standing
	return standing
end

local function placeWard(context: CastContext): boolean
	local hero = context.Caster
	local values = context.Values

	-- Past the cap the oldest ward goes, so placing one never fails.
	local wards = getWards(hero)
	while #wards >= values.MaxWards do
		UnitServerService:RemoveUnit(table.remove(wards, 1) :: Unit)
	end

	local ward = UnitServerService:SpawnUnit({
		Kind = "Ward",
		TypeId = WARD_TYPE_ID,
		Team = hero.Team,
		Stats = UnitCatalog.Units[WARD_TYPE_ID].Stats,
		Position = context.AimPoint,
	})
	table.insert(wards, ward)
	SimClock.delay(values.Duration, function()
		UnitServerService:RemoveUnit(ward)
	end)

	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = context.AimPoint,
		Radius = RING_RADIUS,
		Color = WARD_COLOR,
		Duration = FLASH_DURATION,
	})
	return true
end

local handlers: { [string]: AbilityHandler } = {
	["Trinket.Ward"] = placeWard,
}

return handlers
