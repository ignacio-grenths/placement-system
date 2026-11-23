--!strict

const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")

const GoldServerService = require("../SystemPackage/GoldServerService")

local Module = {}

function Module:Init()
	GoldServerService:SetStartingGold(ProgressionCatalog.StartingGold)
end

return Module
