--!strict

const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const ItemShopServerService = require("../SystemPackage/ItemShopServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

local Module = {}

-- Items can only be bought while standing at your own team's fountain.
local function isAtFountain(_player: Player, hero: UnitTypes.Unit): boolean
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
		})
	end
end

return Module
