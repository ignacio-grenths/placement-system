--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const UnitServerService = require("../SystemPackage/UnitServerService")

-- Studs paths keep from walls: the widest hero's radius plus a little room.
const WALL_CLEARANCE = 2.5

local Module = {}

function Module:Init()
	UnitServerService:SetWalls(MapLayout.Walls, WALL_CLEARANCE)
end

return Module
