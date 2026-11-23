--!strict

const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")

const HeroLevelServerService = require("../SystemPackage/HeroLevelServerService")

local Module = {}

function Module:Init()
	HeroLevelServerService:SetXpCurve(ProgressionCatalog.XpPerLevel)
	HeroLevelServerService:SetRankRules({
		MaxBasicRank = ProgressionCatalog.MaxBasicRank,
		MaxUltimateRank = ProgressionCatalog.MaxUltimateRank,
		UltimateLevels = ProgressionCatalog.UltimateLevels,
	})
end

return Module
