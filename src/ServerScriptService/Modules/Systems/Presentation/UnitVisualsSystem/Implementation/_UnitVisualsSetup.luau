--!strict

const CharacterLookCatalog = require("@game/ServerScriptService/Modules/Data/CharacterLookCatalog")
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")

const UnitVisualsClientService = require("../SystemPackage/UnitVisualsClientService")

-- Figures are drawn larger than their footprint, so they read from the
-- overhead camera.
const FIGURE_SCALE = 1.35
-- The box clicks land on around a figure of scale 1, tall enough to hold its
-- hair under the health bar.
const FIGURE_SIZE = Vector3.new(2.6, 5.6, 2.6)
const CLONE_TRANSPARENCY = 0.5
const SHADOW_COLOR = Color3.fromRGB(95, 60, 175)
const SHADOW_TRANSPARENCY = 0.2
const SOLDIER_SIZE = Vector3.new(2.4, 2.4, 2.4)
const SOLDIER_BOB = 0.2
-- Styles that stand on a glowing ring: monsters in their own color, so a
-- camp reads at a glance, and structures in their team's.
const RINGED_STYLES: { [UnitCatalog.VisualStyle]: boolean? } = {
	Beast = true,
	Tower = true,
	Gate = true,
	Core = true,
}

const CharacterRig = require("../SystemPackage/CharacterRig")

type RigSpec = CharacterRig.RigSpec

local Module = {}

--[[
	Returns the look for a figure at the size it is drawn, or nil with a
	warning when the catalog has none.
]]
local function getLook(lookId: string): RigSpec?
	local look = CharacterLookCatalog.Looks[lookId]
	if not look then
		warn(`CharacterLookCatalog has no look for {lookId}`)
		return nil
	end
	local drawn = table.clone(look)
	drawn.Scale = (look.Scale or 1) * FIGURE_SCALE
	return drawn
end

local function getFigureSize(look: RigSpec?): Vector3
	return FIGURE_SIZE * (if look then look.Scale or 1 else 1)
end

function Module:Init()
	for heroId, hero in HeroCatalog.Heroes do
		local look = getLook(heroId)
		UnitVisualsClientService:RegisterVisual(heroId, {
			Shape = "Block",
			Size = getFigureSize(look),
			Style = "Rig",
			Rig = look,
			HasTeamRing = true,
			ProjectileSpeed = hero.Stats.ProjectileSpeed,
		})
	end

	-- Haru's Echo Clone looks like a see-through Haru.
	local haruLook = getLook("Haru")
	UnitVisualsClientService:RegisterVisual("HaruClone", {
		Shape = "Block",
		Size = getFigureSize(haruLook),
		Style = "Rig",
		Rig = haruLook,
		Transparency = CLONE_TRANSPARENCY,
		HidesHealthBar = true,
	})

	-- Seo Dan's soldiers are shadows: violet and a little see-through.
	UnitVisualsClientService:RegisterVisual("ShadowSoldier", {
		Shape = "Ball",
		Size = SOLDIER_SIZE,
		Color = SHADOW_COLOR,
		Style = "Alien",
		HasTeamRing = true,
		Bob = SOLDIER_BOB,
		Transparency = SHADOW_TRANSPARENCY,
	})
	local knightLook = getLook("ShadowKnight")
	UnitVisualsClientService:RegisterVisual("ShadowKnight", {
		Shape = "Block",
		Size = getFigureSize(knightLook),
		Style = "Rig",
		Rig = knightLook,
		HasTeamRing = true,
		Transparency = SHADOW_TRANSPARENCY,
	})

	for typeId, entry in UnitCatalog.Units do
		local visual = entry.Visual
		-- A unit with a look, like a lane minion, is drawn as a figure dressed
		-- in its team's color.
		local look = if CharacterLookCatalog.Looks[typeId] then getLook(typeId) else nil
		if look then
			UnitVisualsClientService:RegisterVisual(typeId, {
				Shape = "Block",
				Size = getFigureSize(look),
				Style = "Rig",
				Rig = look,
				IsTeamDressed = true,
				ProjectileSpeed = entry.Stats.ProjectileSpeed,
				ProjectileStyle = visual.ProjectileStyle,
			})
			continue
		end
		UnitVisualsClientService:RegisterVisual(typeId, {
			Shape = visual.Shape,
			Size = visual.Size,
			Color = visual.Color,
			Style = visual.Style,
			HasTeamRing = visual.Style ~= nil and RINGED_STYLES[visual.Style] == true,
			Bob = visual.Bob,
			ProjectileSpeed = entry.Stats.ProjectileSpeed,
			ProjectileStyle = visual.ProjectileStyle,
		})
	end
end

return Module
