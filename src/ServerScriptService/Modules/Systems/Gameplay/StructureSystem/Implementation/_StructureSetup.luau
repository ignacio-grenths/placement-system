--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")

const StructureServerService = require("../SystemPackage/StructureServerService")

const UNIT_TYPES_BY_TIER = {
	Outer = "OuterTower",
	Inner = "InnerTower",
	Gate = "Gate",
	Core = "Core",
}

local Module = {}

function Module:Init()
	local lanes: { string } = {}
	for _, lane in MapLayout.LaneNames do
		table.insert(lanes, lane)
	end
	StructureServerService:SetLanes(lanes)

	for _, spot in MapLayout.Structures do
		local typeId = UNIT_TYPES_BY_TIER[spot.Tier]
		StructureServerService:RegisterStructure({
			Id = spot.Id,
			Team = spot.Team,
			Lane = spot.Lane,
			Tier = spot.Tier,
			TypeId = typeId,
			Stats = UnitCatalog.Units[typeId].Stats,
			Position = spot.Position,
		})
	end
end

return Module
