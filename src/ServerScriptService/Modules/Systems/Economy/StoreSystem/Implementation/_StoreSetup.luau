--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const StoreCatalog = require("@game/ServerScriptService/Modules/Data/StoreCatalog")

const StoreServerService = require("../SystemPackage/StoreServerService")

local Module = {}

function Module:Init()
	local coinPrices: { [string]: number } = {}
	for heroId in HeroCatalog.Heroes do
		if not table.find(StoreCatalog.FreeHeroes, heroId) then
			coinPrices[heroId] = StoreCatalog.HeroCoinPrice
		end
	end
	StoreServerService:Configure({
		StarterCoins = StoreCatalog.StarterCoins,
		FreeItems = StoreCatalog.FreeHeroes,
		CoinPrices = coinPrices,
	})
end

return Module
