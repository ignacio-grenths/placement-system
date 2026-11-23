--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const VisionCatalog = require("@game/ServerScriptService/Modules/Data/VisionCatalog")

const VisionClientService = require("../SystemPackage/VisionClientService")

-- Studs of fog past the map's edge, enough to fill the camera's view when
-- it is pulled all the way to an edge.
const FOG_MARGIN = 70

local Module = {}

function Module:Init()
	VisionClientService:Configure({
		Extent = MapLayout.HalfSize + FOG_MARGIN,
		Brushes = MapLayout.Brushes,
		Walls = MapLayout.Walls,
		SightByKind = VisionCatalog.SightByKind,
		Color = VisionCatalog.FogColor,
		Opacity = VisionCatalog.FogOpacity,
	})
end

return Module
