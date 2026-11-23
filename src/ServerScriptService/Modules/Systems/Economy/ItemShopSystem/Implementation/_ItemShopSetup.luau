--!strict

const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const ItemShopServerService = require("../SystemPackage/ItemShopServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

local Module = {}

-- Items can only be bought while standing at your own team's fountain.
local function isAtFountain(hero: UnitTypes.Unit): boolean
	local base = MapLayout.Bases[hero.Team :: MapLayout.MapTeam]
	return base ~= nil and (hero.Position - base.Fountain).Magnitude <= base.FountainRadius
end

function Module:Init()
	ItemShopServerService:SetInventorySize(ItemCatalog.InventorySize)
	ItemShopServerService:SetPurchaseCheck(isAtFountain)
	for itemId, entry in ItemCatalog.Items do
		ItemShopServerService:RegisterItem(itemId, {
			Cost = entry.Cost,
			Kind = entry.Kind,
			Stats = entry.Stats,
			HealAmount = entry.HealAmount,
			HealDuration = entry.HealDuration,
			UpgradeOf = entry.UpgradeOf,
		})
	end

	-- Registered in Order, which settles which bonus wins when a hero
	-- completes two pairs with one purchase.
	local pairIds = {}
	for pairId in ItemCatalog.PairBonuses do
		table.insert(pairIds, pairId)
	end
	table.sort(pairIds, function(first, second)
		return ItemCatalog.PairBonuses[first].Order < ItemCatalog.PairBonuses[second].Order
	end)
	for _, pairId in pairIds do
		ItemShopServerService:RegisterPair(pairId, ItemCatalog.PairBonuses[pairId].Items)
	end
end

return Module
