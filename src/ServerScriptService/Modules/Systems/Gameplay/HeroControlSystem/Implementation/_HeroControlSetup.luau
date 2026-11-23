--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const HeroControlServerService = require("../SystemPackage/HeroControlServerService")

local Module = {}

function Module:Init()
	HeroControlServerService:SetBounds(MapLayout.HalfSize)
end

return Module
