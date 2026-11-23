--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")

const UnitVisualsClientService = require("../SystemPackage/UnitVisualsClientService")

-- Every hero wears the same hover-suit in its own color until its model
-- exists.
const HERO_SIZE = Vector3.new(2.6, 5, 2.6)
const HERO_BOB = 0.1
const CLONE_TRANSPARENCY = 0.5
-- Styles that stand on a glowing ring: monsters in their own color, so a
-- camp reads at a glance, and structures in their team's.
const RINGED_STYLES: { [UnitCatalog.VisualStyle]: boolean? } = {
	Beast = true,
	Tower = true,
	Gate = true,
	Core = true,
}

local Module = {}

function Module:Init()
	for heroId, hero in HeroCatalog.Heroes do
		UnitVisualsClientService:RegisterVisual(heroId, {
			Shape = "Block",
			Size = HERO_SIZE,
			Color = hero.Color,
			Style = "Hero",
			HasTeamRing = true,
			Bob = HERO_BOB,
			ProjectileSpeed = hero.Stats.ProjectileSpeed,
		})
	end

	-- Haru's Echo Clone looks like a see-through Haru.
	UnitVisualsClientService:RegisterVisual("HaruClone", {
		Shape = "Block",
		Size = HERO_SIZE,
		Color = HeroCatalog.Heroes.Haru.Color,
		Style = "Hero",
		Bob = HERO_BOB,
		Transparency = CLONE_TRANSPARENCY,
		HidesHealthBar = true,
	})

	for typeId, entry in UnitCatalog.Units do
		local visual = entry.Visual
		UnitVisualsClientService:RegisterVisual(typeId, {
			Shape = visual.Shape,
			Size = visual.Size,
			Color = visual.Color,
			Style = visual.Style,
			HasTeamRing = visual.Style ~= nil and RINGED_STYLES[visual.Style] == true,
			Bob = visual.Bob,
			ProjectileSpeed = entry.Stats.ProjectileSpeed,
		})
	end
end

return Module
