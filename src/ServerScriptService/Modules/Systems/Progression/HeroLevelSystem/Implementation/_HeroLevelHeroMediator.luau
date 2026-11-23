--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)
const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const HeroLevelServerService = require("../SystemPackage/HeroLevelServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local function onHeroSpawned(hero: Unit, heroId: string)
	local entry = HeroCatalog.Heroes[heroId]
	if entry then
		HeroLevelServerService:Track(hero, entry.SkillOrder)
	end
end

local function onLevelChanged(hero: Unit, level: number)
	local entry = HeroCatalog.Heroes[hero.TypeId]
	if not entry then
		return
	end

	local levelsGained = level - 1
	local stats = table.clone(entry.Stats)
	stats.MaxHealth += entry.Growth.MaxHealth * levelsGained
	stats.Armor += entry.Growth.Armor * levelsGained
	stats.AttackDamage += entry.Growth.AttackDamage * levelsGained
	UnitServerService:SetBaseStats(hero, stats)
	UnitServerService:SetMaxResource(
		hero,
		entry.MaxResource + entry.Growth.MaxResource * levelsGained
	)
end

local function getRespawnDelay(hero: Unit): number
	local level = HeroLevelServerService:GetLevel(hero)
	return ProgressionCatalog.BaseRespawnSeconds
		+ ProgressionCatalog.RespawnSecondsPerLevel * (level - 1)
end

function Module:Init()
	HeroServerService.HeroSpawned:Connect(onHeroSpawned)
	HeroLevelServerService.LevelChanged:Connect(onLevelChanged)
	HeroServerService:SetRespawnDelayProvider(getRespawnDelay)
end

return Module
