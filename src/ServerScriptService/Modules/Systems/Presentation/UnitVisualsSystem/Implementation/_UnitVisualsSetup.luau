--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")

const UnitVisualsClientService = require("../SystemPackage/UnitVisualsClientService")

-- Every hero stands in as the same block until its model exists.
const HERO_SIZE = Vector3.new(2.6, 5, 2.6)
const CLONE_TRANSPARENCY = 0.5

local Module = {}

function Module:Init()
	for heroId, hero in HeroCatalog.Heroes do
		UnitVisualsClientService:RegisterVisual(heroId, {
			Shape = "Block",
			Size = HERO_SIZE,
			Color = hero.Color,
			HasTeamRing = true,
			ProjectileSpeed = hero.Stats.ProjectileSpeed,
		})
	end

	-- Haru's Echo Clone looks like a see-through Haru.
	UnitVisualsClientService:RegisterVisual("HaruClone", {
		Shape = "Block",
		Size = HERO_SIZE,
		Color = HeroCatalog.Heroes.Haru.Color,
		Transparency = CLONE_TRANSPARENCY,
		HidesHealthBar = true,
	})

	for typeId, entry in UnitCatalog.Units do
		UnitVisualsClientService:RegisterVisual(typeId, {
			Shape = entry.Visual.Shape,
			Size = entry.Visual.Size,
			Color = entry.Visual.Color,
			ProjectileSpeed = entry.Stats.ProjectileSpeed,
		})
	end
end

return Module
