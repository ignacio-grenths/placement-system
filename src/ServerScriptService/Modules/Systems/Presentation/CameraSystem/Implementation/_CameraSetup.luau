--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)

const CameraClientService = require("../SystemPackage/CameraClientService")

local Module = {}

local function getLocalHeroPosition(): Vector3?
	local hero = UnitClientService:GetLocalHero()
	if not hero then
		return nil
	end
	local position = UnitClientService:GetRenderPose(hero, UnitClientService:GetRenderTime())
	return position
end

function Module:Init()
	CameraClientService:SetFocusProvider(getLocalHeroPosition)
	CameraClientService:SetBounds(MapLayout.HalfSize)
end

return Module
