--!strict

const GuiService = game:GetService("GuiService")

const GroundPlane = require("@game/ServerScriptService/Modules/Utilities/GroundPlane")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)
const UnitVisualsClientService = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/UnitVisualsSystem/SystemPackage/UnitVisualsClientService"
)

const HeroControlClientService = require("../SystemPackage/HeroControlClientService")

type PickResult = HeroControlClientService.PickResult

local Module = {}

local function pick(ray: Ray): PickResult?
	local hero = UnitClientService:GetLocalHero()
	local unit = UnitVisualsClientService:PickUnit(ray)
	-- An enemy that can't be hit yet, like a shielded inner tower, is walked
	-- toward instead.
	if unit and hero and unit.Team ~= hero.Team and unit.IsTargetable then
		return { Kind = "Attack", UnitId = unit.Id }
	end

	local groundPoint = GroundPlane.intersect(ray)
	if not groundPoint then
		return nil
	end
	return { Kind = "Move", Position = groundPoint }
end

local function getLocalHeroPosition(): Vector3?
	local hero = UnitClientService:GetLocalHero()
	if not hero then
		return nil
	end
	local position = UnitClientService:GetRenderPose(hero, UnitClientService:GetRenderTime())
	return position
end

function Module:Init()
	HeroControlClientService:SetPicker(pick)
	HeroControlClientService:SetHeroPositionProvider(getLocalHeroPosition)
end

function Module:Start()
	-- Heroes walk by tapping the ground, so Roblox's thumbstick and jump
	-- button would do nothing but cover the ability buttons.
	GuiService.TouchControlsEnabled = false
end

return Module
